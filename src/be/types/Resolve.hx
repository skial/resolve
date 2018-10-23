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
        return coerceMacro(expr, expr.typeof().sure(), Context.getExpectedType());
    }

    #if (eval || macro)
    public static function coerceMacro(expr:Expr, typeof:Type, expectedType:Type) {
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
                        if (r != '') ereg = new EReg(r, opt);

                    case TFun(args, ret):
                        rawType = param;

                    case x:
                        #if (debug && coerce_verbose)
                        trace( x );
                        #end

                }

            case x:
                #if (debug && coerce_verbose)
                trace( x );
                #end

        }
        
        var rawComplex = rawType.toComplex();
        var result:Expr = null;

        switch typeof.reduce() {
            case TAnonymous(_.get() => { status: AClassStatics( _.get() => cls )}):
                var path = cls.pack.join('.');
                path += (path.length == 0 ? '' : '.') + cls.name;
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
                #if (debug && coerce_verbose)
                trace( x );
                #end
        }

        #if (debug && coerce_verbose)
        trace( rawComplex.toString() );
        trace( result.toString() );
        #end

        if (result == null) {
            Context.fatalError('Unable to find a matching signature of ${rawType.toComplex().toString()} on ${expr.toString()}.', expr.pos);
        }

        return macro @:pos(expr.pos) ($result:$rawComplex);
    }
    #end

}