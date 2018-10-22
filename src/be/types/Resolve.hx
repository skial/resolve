package be.types;

import haxe.Constraints.Function;

#if (eval || macro)
import haxe.macro.*;

using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;
#end

@:callable @:notNull abstract Resolve<T:Function, @:const R:EReg>(T) {

    @:noCompletion public inline function get():T return this;

    @:from private static inline function fromFunction<T:Function>(v:T):Resolve<T, ~//i> return (cast v:Resolve<T, ~//i>);

    @:from public static macro function coerce<In, Out:Function>(expr:ExprOf<Class<In>>):ExprOf<Resolve<Out, ~//i>> {
        var typeof = expr.typeof().sure();
        var expectedType = Context.getExpectedType();
        var expectedComplex = expectedType.toComplex();
        var rawType = (macro (null:$expectedComplex).get()).typeof().sure();
        var ereg:EReg = null;

        switch expectedType.reduce() {
            case TAbstract(_, params):
                for (param in params) switch param {
                    case TInst(_.get() => {kind:KExpr({expr:EConst(CRegexp(r, opt)), pos:p})}, _):
                        #if (debug && coerce_verbose)
                        trace( r, opt );
                        #end
                        ereg = new EReg(r, opt);

                    case TFun(args, ret):
                        rawType = param;

                    case x:
                        #if (debug && coerce_verbose)
                        trace( x );
                        #end

                }

            case x:
                trace( x );

        }
        
        var rawComplex = rawType.toComplex();
        var result:Expr = null;

        switch typeof.reduce() {
            case TAnonymous(_.get() => { status: AClassStatics( _.get() => cls )}):
                var path = cls.pack.join('.');
                path += (path == '' ? '' : '.') + cls.name;
                var tpath = path.asTypePath();
                var matches = [];
                var eregMatch = true;

                for (field in cls.statics.get()) {
                    #if (debug && coerce_verbose)
                    trace( field.name );
                    if (ereg != null) trace( ereg.match( field.name ) );
                    #end
                    if (ereg != null) eregMatch = ereg.match(field.name);
                    if (eregMatch && field.type.unify(rawType)) matches.push( field );

                }
                
                if (matches.length > 0) result = '$path.${matches[matches.length-1].name}'.resolve();

            case x:
                //strace( x );
        }

        #if (debug && coerce_verbose)
        trace( rawComplex.toString() );
        trace( result.toString() );
        #end
        return macro @:pos(expr.pos) ($result:$rawComplex);
    }

}