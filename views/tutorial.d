import core.reflect.reflect;
import core.stdc.stdio;

// core.reflect.reflect is a module which contains the visitor and public imports all the druntime node definitions

// core.reflect is based on one magic function "nodeFromName"
// the function takes a "string" which is the name of the declaration you want to reflect over.
// additionally you can specify reflect flags which determine how "deep" the reflection should be.
// by default you get the most shallow reflection. Which does not include members or fields nor does it include lexical parents.
// for useful information you will mostly want the ReflectFlags.Members to be set.

pragma(msg, "ReflectFlags:\n", (const Node node) {
    import std.algorithm;
    import std.array;
    import std.conv;

    return (cast(EnumDeclaration) node).members.map!(
        m => "  " ~ m.name ~ " = " ~ (cast(IntegerLiteral) m.value).value.to!string) // don't worry too much about the cast all of that can be hidden by library code.
    .join("\n");
    // I happen to know that ReflectFlags are an enum which is why I do a dynmaic cast from Node
    // to EnumDeclaration so I can use the function memberNames defined above to print it's members
    // in the output on the right you should be able to see fields of the class EnumDeclaration
    // if you scroll down a little.
}(nodeFromName("ReflectFlags", ReflectFlags.Members)));
// NOTE it is important to use nodeFromName as an argument and not inside the lambda
// because the lambda will go through codegen and will try to generate the code
// for nodeFromName which it cannot since it's magic ;)

// above is an example which will print the reflect flags that you can specify.

// now let's use core.reflect to explore core.reflect.
// in order to do that we need a list of all the modules that define node classes
// or a 'name' of some struct template or module that imports them
// which we could then see via import reflection.
// As noted above 'core.reflect.reflect' does pulicly import them
// but unfortunately it doesn't have an identifier which we could refer to.
// ... the way to solve that is to use an import-binding
import core_reflect = core.reflect.reflect;

// now we have a name :)
// let's create a reflection from it with Member MemberRecursion and Imports enabled.
static const core_reflect_reflection = nodeFromName("core_reflect",
        ReflectFlags.Members | ReflectFlags.MemberRecursion
        | ReflectFlags.Imports | ReflectFlags.ImportRecursion);
// but how do we now get all the class declarations to print out our fields?
// by subclassing a TransitiveVisitor

import core.reflect.transitiveVisitor;

// let's define a convenient instantiating function to get our class names and the defined fields
string classNamesAndFields(const Node root, const Node filterBase = null)
{
    // in here we now subclass our visitor
    final class ClassAndFieldVisitor : TransitiveVisitor
    {
        string result;

        alias visit = TransitiveVisitor.visit; // magic line to merge overlaod sets ... don't worry about it
        // now we override the visit function for ClassDeclarations()
        override void visit(ClassDeclaration cd)
        {
            if (cd.internalPointer in seenNodes)
                return;
            // the transitive visitor keeps track of the nodes it has visited
            // to avoid getting into a infinite recursion when a node references itself
            // we can use that information to avoid prining the same node twice

            if (auto base = cast(ClassDeclaration) filterBase)
            {
                if(!base.isBaseOf(cd))
                {
                    return ;
                }
            }
            // we also want to avoid printing classes which do not inherit from the filterBase.
            
            result ~= "\nclass ";
            result ~= cd.name;

            if (cd.base)
            {
                result ~= " : ";
                result ~= cd.base.name;

            }
            result ~= "\n{";

            if (cd.fields !is null)
                result ~= "\n";
            foreach (field; cd.fields)
            {
                result ~= "    ";
                result ~= field.type.identifier;
                result ~= " ";
                result ~= field.name;
                result ~= ";\n";
            }
            result ~= "}\n";
            super.visit(cd);
            // we could skip this since we know we visit the base class anyways.
            // however it is good to keep in mind that you to call the super.visit method to get fully transitive iteration
        }
    }
    // and that's it.

    scope fieldPrinter = new ClassAndFieldVisitor();
    // make an instance of our visitor since it doesn't hold much state,
    // it's fine to use 'scope' to allocate it on the stack.
    (cast() root).accept(fieldPrinter);
    // we need to cast() here because accept does not work with cost nodes.
    // call the accept method of the root to start visitation
    return fieldPrinter.result;
    // and return the accumulated result of the visitor;
}

bool isBaseOf(const ClassDeclaration base,const ClassDeclaration cd) pure
{
    ClassDeclaration currentBase = cast()cd.base;
    while(currentBase)
    {
        if (currentBase is base)
            return true;
        currentBase = cast()currentBase.base;
    }
    
    return false;
}
static const node_base = nodeFromName("Node");
pragma(msg, classNamesAndFields(core_reflect_reflection, node_base));
