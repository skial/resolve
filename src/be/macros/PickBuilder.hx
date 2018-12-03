package be.macros;

import haxe.macro.Type;
import haxe.macro.Expr.TypePath;
import haxe.macro.Expr.ComplexType;
import haxe.macro.*;
import tink.macro.BuildCache;

using tink.MacroApi;

/**
Provides a way to select any method that satifies
    - expected arg types
    - expected return type
    - method names using a regex
---
be.types.Pick<String->Int>                      // Any method that unifies with String->Int signature.
be.types.Pick<String->Rest->Int>                // Any method that has non optional String, zero or more optional args, and returns Int.
be.types.Pick<Int->Self>                        // Any method that unifies with Int->Self. Self means the method returns a type that can unify with the type/module whatever.
be.types.Pick<Int->Self, ~/from[a-zA-Z]+/>      // Same as before, but uses a regular expression to filter method names.
**/

class PickBuilder {

    public static function search() {
        return BuildCache.getTypeN('be.types.Pick', function(ctx:BuildContextN) {
            var typeName = ctx.name;
            var signature = null;
            var signatureType = null;
            var signatureComplex = null;
            var reg = null;
            var ereg = macro ~//;
            var filter:EReg = null;
            var ctor = 'be.types.$typeName'.asTypePath();
            
            for (type in ctx.types) {
                switch type {
                    case TFun(args, ret) if (signature == null):
                        signature = {args:args, ret:ret};
                        signatureType = type;
                        signatureComplex = signatureType.toComplex();

                    case TInst(_.get() => {kind:KExpr( e = {expr:EConst( CRegexp(r, opt) ), pos:pos} )}, _):
                        reg = {r:r, opt:opt};
                        filter = new EReg(r, opt);
                        ereg = e;

                    case x:
                        #if (debug && coerce_verbose)
                        trace( x );
                        #end
                }
            }

            var ctype = macro:be.types.Resolve<$signatureComplex>;
            var td = macro class $typeName {
                public inline function new(v:$ctype) this = v;
                @:to public inline function toResolve():$signatureComplex return this;
                //@:to public inline function toFunction() return this.get();
                @:from public static inline function fromResolve(r:$ctype) return new $ctor(r);
                @:from public static inline function fromFunc(r:$signatureComplex) return new $ctor(r);
            }
            
            switch ctype {
                case TPath({params:params}):
                    // Manually insert TPExpr as `macro:be.types.Resolve<$signatureComplex, $ereg>` fails
                    params.push( TPExpr(ereg) );

                case x:
                    trace(x);
            }
            td.kind = TDAbstract(ctype, [ctype], [ctype]);
            td.meta = [
                {name:':forward', params:[], pos:ctx.pos}, 
                {name:':forwardStatics', params:[], pos:ctx.pos}, 
                {name:':notNull', params:[], pos:ctx.pos}, 
                {name:':callable', params:[], pos:ctx.pos}
            ];

            #if (debug && coerce_verbose)
            trace( new Printer().printTypeDefinition(td) );
            #end

            return td;
        });
    }

    public static function foo(expr:Expr):Expr {
        return macro {};
    }

}