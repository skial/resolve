package be.macros;

import haxe.macro.Type;
import haxe.macro.Defines;
import be.macros.Resolver.LocalDefines;
import haxe.macro.Expr.TypePath;
import haxe.macro.Expr.ComplexType;
import haxe.macro.*;

using tink.MacroApi;
using haxe.macro.TypeTools;

class PickBuilder {

    public static function search() {
        var type = Context.getLocalType();
        var pos = Context.currentPos();
        var debug = true;//Defines.Debug && CoerceVerbose;

        var signature = null;
        var signatureType = null;
        var signatureComplex = null;
        var fieldEReg:Expr = macro ~//i;
        var metaEReg:Expr = macro ~//i;
        var key = '';

        switch type {
            case TInst(_, params) if (params.length != 0):
                for (param in params) {
                    switch param {
                        case TFun(args, ret) if (signature == null):
                            signature = {args:args, ret:ret};
                            signatureType = param;
                            signatureComplex = signatureType.toComplex();
                            key += type.getID();

                        // @see https://haxe.org/manual/expression.html#define-identifier
                        // Checking for `@` in ereg _should_ be safe to detect metadata ereg's.
                        case TInst(_.get() => {kind:KExpr( e = {expr:EConst( CRegexp(r, opt) ), pos:pos} )}, _) if (fieldEReg != null && r.indexOf('@') == -1):
                            fieldEReg = e;
                            key += r + opt;

                        case TInst(_.get() => {kind:KExpr( e = {expr:EConst( CRegexp(r, opt) ), pos:pos} )}, _) if (metaEReg != null && r.indexOf('@') > -1):
                            metaEReg = e;
                            key += r + opt;

                        case x:
                            if (debug) {
                                trace( x );
                            }

                    }

            }

            case x:
                if (debug) trace( x );
                /**
                    If no parameters are found, its likely an import, or fully qualified usage.
                **/
                return macro:be.types.ResolveFunctions;
        }

        if (debug) {
            trace( 'signature       :   ' + signatureType == null ? null : signatureType.toString() );

        }

        if (fieldEReg == null) fieldEReg = macro ~//i;
        if (metaEReg == null) metaEReg = macro ~//i;

        var ctype = macro:be.types.ResolveMethod;//<$signatureComplex>;
        switch ctype {
            case TPath({params:params}):
                params.push( TPType(signatureComplex) );
                // Manually insert TPExpr, as `macro:be.types.Resolve<$signatureComplex, $fieldEReg, $metaEReg>` fails.
                params.push( TPExpr(fieldEReg) );   // field name regular expression.
                params.push( TPExpr(metaEReg) );    // field metadata regular expression.

            case x:
                if (debug) trace(x);

        }

        if (debug) {
            trace( ctype/*.toString()*/ );
        }

        return ctype;
    }

}