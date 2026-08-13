package backend;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

class MacroBridge
{
    /**
     * Automatically extracts every variable from an abstract at compile-time 
     * and returns a completely dynamic object containing those values at runtime.
     */
    public static macro function exposeAbstract(className:String):Expr
    {
        var fields:Array<ObjectField> = [];
        
        switch (Context.getType(className))
        {
            case TAbstract(abstractType, _):
                // Scan every static variable inside the abstract definition
                for (field in abstractType.get().impl.get().statics.get())
                {
                    if (field.kind.match(FVar(_, _)))
                    {
                        var fieldName = field.name;
                        // Build a compile-time expression linking the key to the value
                        fields.push({
                            field: fieldName,
                            expr: Context.parse(className + "." + fieldName, Context.currentPos())
                        });
                    }
                }
            default:
                Context.error("MacroBridge error: " + className + " is not an abstract type.", Context.currentPos());
        }
        
        return { expr: EObjectDecl(fields), pos: Context.currentPos() };
    }
}
