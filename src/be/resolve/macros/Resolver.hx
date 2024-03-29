package be.resolve.macros;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Metas;
import haxe.macro.Defines;
import be.resolve.Errors;
import be.resolve.ResolveTask;

using StringTools;
using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;
using haxe.macro.TypeTools;

@:forward
@:forwardStatics
enum abstract LocalDefines(Defines) {
    public var ResolveVerbose = 'resolve_verbose';
    
    @:to public inline function asBool():Bool {
		return haxe.macro.Context.defined(this);
	}

    @:op(A == B) private static function equals(a:LocalDefines, b:Bool):Bool;
    @:op(A && B) private static function and(a:LocalDefines, b:Bool):Bool;
    @:op(A != B) private static function not(a:LocalDefines, b:Bool):Bool;
    @:op(!A) private static function negate(a:LocalDefines):Bool;
}

@:forward
@:forwardStatics
enum abstract LocalMetas(Metas) to String {
    public var ResolverBind = ':resolver.self.bind';
}

@:structInit
class TypeParamSet {

    public var concreteTypes:Array<Type>;
    public var typeParameters:Array<TypeParameter>;

    public inline function new(concreteTypes:Array<Type>, typeParameters:Array<TypeParameter>) {
        this.concreteTypes = concreteTypes;
        this.typeParameters = typeParameters;
    }

}

@:structInit
@:using(be.resolve.macros.Resolver.TypeParamInfoUsings)
class TypeParamInfo extends TypeParamSet {
    public var constraints:Array<Array<Type>>;

    public inline function new(concreteTypes:Array<Type>, constraints:Array<Array<Type>>, typeParameters:Array<TypeParameter>) {
        this.constraints = constraints;
        super(concreteTypes, typeParameters);
    }

}

class TypeParamInfoUsings {

    public static function reduce(info:TypeParamInfo):TypeParamSet {
        var set:TypeParamSet = { concreteTypes: info.concreteTypes.copy(), typeParameters: info.typeParameters.copy() };

        for (index in 0...info.typeParameters.length) {
            var param = info.typeParameters[index];
            var type = info.concreteTypes[index];
            var candidates = info.constraints[index];

            if (candidates != null && candidates.length > 0) {
                type = candidates[0];

            }

            set.concreteTypes[index] = type;

        }

        return set;
    }

}

class Resolver {

    private static final printer = new haxe.macro.Printer();

    @:persistent public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro (v -> v),
        'Bool' => macro (v -> v.toLowerCase() == 'true'),
    ];

    @:persistent public static var intMap = [
        'String' => macro Std.string,
    ];

    @:persistent public static var floatMap = [
        'String' => macro Std.string,
        'Date' => macro std.Date.fromTime,
    ];

    @:persistent public static var boolMap = [
        'String' => macro Std.string,
    ];
    
    @:persistent public static var typeMap = [
        'String' => stringMap,
        'Int' => intMap,
        'Float' => floatMap,
        'Bool' => boolMap,
        //'Array' => new Map()
    ];

    private static final typeParamEReg:EReg = ~/^(?:[a-zA-Z0-9<> ]*: ?((?:[A-Z][a-zA-Z0-9]*)+))$/gm;

    public static function getTypeParameters(type:Type, debug:Bool = false):Null<TypeParamInfo> {
        var constraints:Array<Array<Type>> = [];
        var concreteTypes:Array<Type> = [];
        var typeParameters:Array<TypeParameter> = [];

        switch type {
            case TType(_.get() => def, params):
                concreteTypes = params;
                typeParameters = def.params;

            case TInst(_.get() => cls, params):
                concreteTypes = params;
                typeParameters = cls.params;

            case TAbstract(_.get() => abs, params):
                concreteTypes = params;
                typeParameters = abs.params;

            case TEnum(_.get() => enm, params):
                concreteTypes = params;
                typeParameters = enm.params;

            case x:
                if (debug) trace( x );
        }

        for (index in 0...typeParameters.length) {
            var typeParam = typeParameters[index];
            var passedParam = concreteTypes[index];

            switch [typeParam.t, passedParam] {
                /**
                    A monomorph at this point that is null, is useless, especially when
                    the compiler knows what it might be, but doesnt tell us. See next comment.
                **/
                case [TInst(_.get() => cls = {kind:KTypeParameter(c)}, params), TMono(_.get() => t)]:
                    if (debug) trace( params.map( p -> p.toString() ));

                    /**
                        Outputs something along the lines of `Unknown<0> : Float`,
                        BUT! digging into the `type`, the type constraint `Float`, afaik, is
                        nowhere to be found, thru the public api at least.
                    **/
                    if (t == null) {
                        var stringy = passedParam.toString();

                        if (typeParamEReg.match( stringy )) {
                            var typeId = typeParamEReg.matched(1);

                            try {
                                c.push( Context.getType(typeId) );

                            } catch(e) {
                                if (debug) trace( e );

                            }

                        }

                    }

                    constraints.push( c );

                case [a, b]:
                    if (debug) trace( a, b );
                    constraints.push( [b] );

            }

        }

        if (debug) {
            trace( '<type parameters ...>' );
            trace( 'typeParameters      :   ' + typeParameters );
            trace( 'concreteTypes       :   ' + concreteTypes );
            trace( 'constraints         :   ' + constraints );
        }

        return { typeParameters:typeParameters, concreteTypes:concreteTypes, constraints:constraints };
    }

    public static function determineTask(expr:Expr, input:Type, output:Type, ?debug:Bool):ResolveTask {
        if (debug == null) debug = Debug && ResolveVerbose;
        var result:ResolveTask = null;

        //var rawInput = input.followWithAbstracts();
        //  Assume its in a raw form, i.e not an abstract or typedef redeclaration.
        var rawOutput = output;
        var isResolve = false;
        var fieldString = '';
        var metaString = '';
        var fieldEReg = ~//i;
        var metaEReg = ~//i;

        var typeInfo = getTypeParameters( output, debug );
        var reduced = typeInfo.reduce();

        // Check if its a redefined type first.
        // typedef Name = Resolve<T, ~/field/, ~/@:meta/>;
        switch output {
            case TType(_.get() => def, _):
                if (debug) {
                    trace( 'was      :   ' + output.toString() );

                }

                output = def.type;

                if (debug) {
                    trace( 'now      :   ' + output.toString() );

                }

            case _:

        }

        var sealedType = output.applyTypeParameters( reduced.typeParameters, reduced.concreteTypes);

        switch sealedType {
            // Remember there are currently two types, both starting with "Resolve"
            case TAbstract(_.get() => abs = {name:_.startsWith('Resolve') => true}, params): 
                isResolve = true;
                // Correct the `rawOutput` type.
                rawOutput = params[0];

                // Extract the EReg constants.
                for (i in 1...3) if (params[i] != null) switch params[i] {
                    case TInst(_.get() => {kind:KExpr(_.expr => EConst(CRegexp(r, o)))}, _):
                        if (debug) {
                            trace( i, r, o );
                        }
                        if (i == 1) fieldEReg = new EReg(fieldString = r, o);
                        if (i == 2) metaEReg = new EReg(metaString = r, o);

                    case x:
                        if (debug) trace( x );

                }
                
            case x: 
                if (debug) trace( x );

        }

        var isMethod = switch rawOutput {
            case TFun(_, _): true;
            case _: false;
        }
        
        if (debug) {
            trace( '<info ...>' );
            trace( 'expression      :   ' + expr.toString() );
            trace( 'input type      :   ' + input );
            trace( '⨽ reduced       :   ' + input.reduce() );
            trace( 'output type     :   ' + output );
            trace( '⨽ reduced       :   ' + rawOutput );
            trace( 'function?       :   ' + isMethod );
            trace( 'resolve?        :   ' + isResolve );
            trace( 'field ereg      :   ' + fieldEReg );
            trace( 'meta ereg       :   ' + metaEReg );
        }

        if (isMethod) {
            switch input.reduce() {
                // var _:Resolve<$rawOutput, EReg, EReg> = Abstract;
                case TAnonymous(_.get() => {status:AClassStatics((clsr = _.get() =>  {kind:KAbstractImpl(absr)})) }):
                    if (debug) trace( 'static abstract    :   ' + absr.toString() );
                    var ident = absr.toString().resolve();
                    var tasks = [
                        SearchMethod(rawOutput, TInst(clsr, []), true, ident, fieldEReg, metaEReg),
                        SearchMethod(rawOutput, TAbstract(absr, []), true, ident, fieldEReg, metaEReg),
                    ];
                    result = Multiple(tasks);
                
                // var _:Resolve<$rawOutput, EReg, EReg> = Class;
                case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                    if (debug) trace( 'static class    :   ' + ref.toString() );
                    result = SearchMethod(rawOutput, TInst(ref, []), true, ref.toString().resolve(), fieldEReg, metaEReg);

                /*
                var instance:Class = new Class();
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TInst(ref = _.get() => cls, params) if (cls.constructor != null && !cls.meta.has(Metas.CoreApi)):
                    if (debug) trace( 'instance class    :   ' + cls.name );
                    result = SearchMethod(rawOutput, TInst(ref, params), false, expr, fieldEReg, metaEReg);

                /*
                var instance:Abstract = new Abstract()/implicit or passive cast;
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TAbstract(absr = _.get() => abs, params):
                    if (debug) trace( 'Instance Abstract   :   ' + absr.toString() );
                    var clsr = abs.impl;
                    var tasks = [];

                    if (clsr != null) {
                        if (debug) trace( 'Checking the abstract implemenation class for instance fields.' );
                        // Check the implementation class for instance fields first.
                        tasks.push( SearchMethod(rawOutput, TInst(clsr, []), false, expr, fieldEReg, metaEReg) );

                    }

                    if (metaString != '') {
                        if (debug) trace( 'Checking Abstract instance & static fields');
                        // It has a metadata ereg, so set the abstract to be checked.
                        tasks.push( SearchMethod(rawOutput, TAbstract(absr, params), true, absr.toString().resolve(), fieldEReg, metaEReg) );
                        tasks.push( SearchMethod(rawOutput, TAbstract(absr, params), false, expr, fieldEReg, metaEReg) );
                    }

                    result = (tasks.length == 1) ? tasks[0] : Multiple(tasks);

                case x:
                    throw x;

            }

        } else if (isResolve && !isMethod) {
            var _type = input.reduce();
            var isStatic = false;

            switch _type {
                case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                    _type = TInst(ref, []);
                    isStatic = true;

                case TAnonymous(_.get() => {status:AClassStatics((clsr = _.get() =>  {kind:KAbstractImpl(absr)})) }):
                    _type = TInst(clsr, []);
                    isStatic = true;

                case TAbstract(_.get() => abs, params):
                    if (abs.impl != null) {
                        _type = TInst(abs.impl, params);
                        isStatic = true;

                    }
                
                case x:
                    if (debug) trace( x );

            }

            result = SearchProperty(rawOutput, _type, isStatic, expr, fieldEReg, metaEReg);

        } else {
            // var _:$output = coerce($expr:$input);
            result = ConvertValue(input, rawOutput, expr);

        }

        if (debug) {
            switch result {
                case Multiple(tasks):
                    trace('<Multiple>');
                    for (task in tasks) trace( task );

                case _:
                    trace(result);

            }

        }

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type, meta:Metadata}>, Error> {
        if (debug == null) debug = Debug && ResolveVerbose;
        var results = [];
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (debug) {
            trace( 'sig         :   ' + signature );
            trace( 'use statics :   ' + statics );
            trace( 'field ereg  :   ' + fieldEReg );
            trace( 'meta ereg   :   ' + metaEReg );
        }

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();

                if (debug) {
                    trace( 'type        :   ' + moduleID );
                    trace( 'args        :   ' + args );
                    trace( 'return type :   ' + ret );
                }

                var fields:Array<ClassField> = switch module {
                    // The class which is auto generated for abstracts.
                    case TInst(clsr = _.get() => cls = {kind:KAbstractImpl(absr)}, params):
                        if (debug) {
                            trace( "Instance abstract `new T`" ); 
                        }
                        
                        var fs:Array<ClassField> = [];
                        // Afaik, all abstract methods get converted to statics?
                        var sfields = cls.statics.get();

                        if (!statics) {
                            var abs = absr.get();
                            // Get the underlying type of the Abstract
                            var raw = abs.type;
                            /**
                                The compiler used to mark all non static fields in an
                                Abstract which would be converted to statics with
                                `@:impl` metadata, which helped reduce fields to check
                                against.
                                ---
                                All the tests still pass, hopefully it was a pointless check
                                in this first place.
                            **/
                            var impls = sfields;//.filter( f -> f.meta.has(Metas.Impl) );
                            
                            for (field in impls) {
                                switch field.type.follow() {
                                    case x = TFun(args, ret):
                                        if (debug) {
                                            trace( args.length, args );
                                            trace( args[0].t, args[0].t.followWithAbstracts(), args[0].t.followWithAbstracts().unify(raw) );

                                        }
                                        /**
                                            Since we are searching an Abstract type as an instance/reference,
                                            e.g `_:Resolve<_, _, _> = ref;` the type signature needs patching.
                                            ---
                                            Abstract fields that are written as non static fields get
                                            converted to static fields, with the Abstract type as the first arg.
                                            `function foo(v:String):Bool` -> `static function foo(self:Abs, v:String):Bool`
                                            ---
                                            Pop the first arg off the type signature but mark the type with
                                            `@:resolver.self.bind`, this is needed when creating the call expression.
                                        **/
                                        if (args.length > 1 && args[0].t.followWithAbstracts().unify(raw)) {
                                            field.meta.add( ResolverBind, [macro $v{args.length-1}], field.pos );
                                            var _field = Reflect.copy(field);
                                            _field.type = TFun(args.slice(1), ret);
                                            fs.push( _field );

                                        } else {
                                            if (debug) trace( field.name, x );

                                        }

                                    case x:
                                        if (debug) trace( field.name, x );

                                }

                            }

                        } else {
                            // See `@:impl` commment above.
                            for (field in sfields) if (field.kind.match( FMethod(_) ))/*if (!field.meta.has(Metas.Impl))*/ {
                                fs.push( field );
                            }

                        }

                        fs;

                    case TInst(_.get() => cls, params):
                        if (debug) trace( 'Class' );
                        var fs:Array<ClassField> = statics ? cls.statics.get() : cls.fields.get();
                        fs.filter( f -> f.kind.match( FMethod(_) ));

                    case TAbstract(_.get() => abs, params) if (metaEReg != null):
                        if (debug) {
                            trace( 'Abstract `:T`' );
                            trace( 'Check statics:  $statics' );
                        }

                        var fs:Array<ClassField> = [];

                        if (statics) {
                            /**
                                Abstract features, dependent on metadata has already been parsed by the compiler,
                                but we still have to check the regular expression matches, manually.
                            **/
                            if (metaEReg.match('@' + Metas.From)) {
                                for (f in abs.from) if (f.field != null) {
                                    fs.push( f.field );
    
                                }
    
                            }
                            
                            // Check all Binops
                            var op = '@' + Metas.Op;
                            var binop = ['+', '-', '/', '*', '<<', '>>', '>>>', '|', '&', '^', '%', '=', '!=', '>', '>=', '<', '<=', '&&', '||', '...', '=>', 'in'];
                            // Push binop assigns operators. Eg. `+=` or `*=`.
                            for (i in 0...12) binop.push( binop[i] + '=' );
                            
                            if (debug) trace( metaEReg );
                            for (b in binop) {
                                if (metaEReg.match(op + '(A $b B)')) {
                                    if (debug) {
                                        trace( metaEReg );
                                        trace( 'Matched binop:  $b' );
                                    }

                                    for (f in abs.binops) if (f.field != null) {
                                        if (debug) trace( 'Adding @:op overload `$b` method ${f.field.name}' );
                                        fs.push( f.field );
                                    }

                                    // TODO Should we break on the first match...
                                    break;
                                }

                            }
    
                            var unop = ['++', '--', '!', '-', '~'];
                            for (u in unop) if (metaEReg.match(op + '(${u}A)')) {
                                for (f in abs.unops) if (f.field != null) {
                                    fs.push( f.field );
                                }

                                // TODO Should we break on the first match...
                                break;
                            }

                            // Check postfix.
                            for (u in ['++', '--']) if (metaEReg.match(op + '(A$u)')) {
                                for (f in abs.unops) if (f.field != null) {
                                    fs.push( f.field );
                                }
                                break;
                            }
    
                            // Check array access
                            if (metaEReg.match(op + '([])') || metaEReg.match('@' + Metas.ArrayAccess)) for (f in abs.array) {
                                fs.push( f );
                            }

                            // Check resolve
                            if (metaEReg.match(op + '(a.b)') || metaEReg.match('@' + Metas.Resolve)){
                                if (abs.resolve != null) fs.push( abs.resolve );
                                if (abs.resolveWrite != null) fs.push( abs.resolveWrite );
                            }

                        } else {
                            // Check @:to implicit casts
                            if (metaEReg.match('@' + Metas.To)) for (f in abs.to) {
                                fs.push( f.field );
                            }

                        }

                        fs;

                    case x:
                        if (debug) {
                            trace(x);
                        }

                        [];

                }

                var _pairs:Array<Pair<ClassField, Int>> = [
                    for (field in fields) {
                        if (field.name != '') {
                            var weight = filterFields(field, signature, fieldEReg, metaEReg, debug);

                            if (weight > 0) {
                                new Pair(field, weight);
            
                            }
            
                        }
                    }
                ];

                if (debug) {
                    trace( 'checking    :   ' + fields.map( f->f.name ) );
                }

                haxe.ds.ArraySort.sort( _pairs, function(a, b) {
                    var wA = a.b;
                    var wB = b.b;
                    return wA - wB;
                } );

                if (debug) {
                    trace( 'sorted      :   ' + _pairs.map( p -> p.a.name ) );
                }

                results = _pairs.map( p -> { name:p.a.name, type:p.a.type, meta:p.a.meta.get() } );

            case x:
                return Failure(new Error( NotFound, NotFunction + ' Not ${x.getID()}', pos ));

        }

        return Success(results);
    }

    public static function findProperty(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type, meta:Metadata}>, Error> {
        if (debug == null) debug = Debug && ResolveVerbose;
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (debug) {
            trace( 'module  :   ' + module.getID() );
        }

        var fields = switch module {
            case TInst(_.get() => cls, _):
                if (statics) {
                    cls.statics.get();

                } else {
                    cls.fields.get();

                }

            case x:
                if (debug) trace( x );
                [];

        }

        var _pairs:Array<Pair<ClassField, Int>> = [
            for (field in fields) {
                if (!field.kind.match( FMethod(_) )) {
                    var weight = filterFields(field, signature, fieldEReg, metaEReg, debug);
                    if (weight > 0) {
                        new Pair(field, weight);
    
                    }
    
                }
            }
        ];

        haxe.ds.ArraySort.sort( _pairs, function(a, b) {
            var wA = a.b;
            var wB = b.b;
            return wA - wB;
        } );

        if (debug) {
            trace( '<property weights ...>' );
            for (pair in _pairs) trace( pair.a.name, pair.b );
        }

        return Success(_pairs.map( p -> { name:p.a.name, meta:p.a.meta.get(), type:p.a.type }));
    }

    /**
        The returned value is the weight, based on the factors that the field matched against. Higher equals more specific.
    **/
    private static function filterFields(field:ClassField, signature:Type, ?fieldEReg:EReg, ?metaEReg:EReg, debug:Bool = false):Int {
        var weight = 0;
        var ftype = field.type.followWithAbstracts();
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');

        if (debug) {
            trace( '<filtering properties>' );
            trace( 'field name      :   ' + field.name );
            trace( '⨽ type          :   ' + ftype.toString() );
            trace( '<matching against ...>' );
            trace( 'signature       :   ' + signature.toString() );
            trace( '<comparison ...>' );
            trace( 'equality        :   ' + ftype.compare( signature ) );
            trace( '<checks ...>' );
            trace( 'empty field ereg:   ' + blankField );
            trace( 'empty meta ereg :   ' + blankMeta );
        }

        // `compare` is from tink_macro `Types.hx`
        if (ftype.compare( signature ) == 0) {
            if (debug) trace( 'type equality    :   true' );
            weight++;
        }
        
        /**
            `type1.unify(type2)` which calls an internal compiler function,
            seems to trigger some state, via tmono's? 🤷‍♀️
            This can cause abstract types with macro methods, with define guarded fields,
            to resolve types incorrectly and throw a compiler error.
        **/
        /*if (ftype.unify(signature)) {
            if (debug) trace( 'type unity      :   true' );
            weight++;
        }*/
        /**
            Comparing the `field.type` against the `signature` manaually, assuming dynamic
            and monomorph types equate with any other type, use `tink_macro`'s compare which
            recurses Types enum, using indexes and string comparions for equality.
        **/
        function compare(a:Type, b:Type):Int {
            return switch [a, b] {
                case [TDynamic(t) | TMono(_.get() => t), _ ] | [_, TDynamic(t) | TMono(_.get() => t)] if (t == null):
                    0;

                case [a, b]: a.compare(b);
            }
        }
        switch [signature, ftype] {
            case [TFun(args1, ret1), TFun(args2, ret2)]:
                var retDistance = compare( ret1, ret2 );
                var fargs1 = args1.filter( a -> !a.opt );
                var fargs2 = args2.filter( a -> !a.opt );

                if (retDistance == 0 && fargs1.length > 0 && fargs1.length == fargs2.length) {
                    var argDistance = 0;
                    for (index in 0...fargs1.length) {
                        var a = fargs1[index];
                        var b = fargs2[index];
                        if (a == null || b == null) break;
                        var distance = compare( a.t, b.t);
                        argDistance += distance;
                    }

                    if (argDistance == 0) weight++;

                }

            case [a, b]:
                if (debug) trace( field.name, a , b );

        }
        
        if (!blankField && fieldEReg.match( field.name )) {
            if (debug) trace( 'field match     :   true' );
            weight++;
        }

        if (!blankMeta && field.meta.get().filter( m -> metaEReg.match( printer.printMetadata(m) )).length > 0) {
            if (debug) trace( 'meta match      :   true' );
            weight++;
        }

        return weight;
    }

    public static function convertValue(input:Type, output:Type, value:Expr, ?debug:Bool):Outcome<Expr, Error> {
        if (debug == null) debug = Debug && ResolveVerbose;
        var inputID = input.getID();
        var outputID = output.getID();
        var pos = value.pos;

        if (debug) {
            trace( '<convert value ...>' );
            trace( 'input       :   ' + input );
            trace( 'output      :   ' + output );
            trace( 'value       :   ' + value.toString() );
            trace( 'input id    :   ' + inputID );
            trace( 'output id   :   ' + outputID );
        }
        
        if (typeMap.exists( inputID )) {
            var sub = typeMap.get( inputID );
            if (sub.exists( outputID )) {
                return Success( macro @:pos(pos) $e{sub.get( outputID )}($value) );

            }

        }

        var isAbstract = output.reduce().match(TAbstract(_, _));
        var outputComplex = output.toComplexType();
        var unified = ( isAbstract && (macro ($value:$outputComplex)).typeof().isSuccess() ) || 
        ( input.unify(output) || input.unify(output.follow()) || input.follow().unify(output) || input.follow().unify(output.follow()) );

        if (debug) {
            trace( 'unified         :   ' + unified );
            trace( 'is abstract     :   ' + isAbstract );
            trace( 'out ctype       :   ' + outputComplex.toString() );
        }

        if (unified) {
            return Success( macro @:pos(pos) ($value:$outputComplex) );

        }

        var error:Error = null;
        var outMatchesArray = (macro new Array()).typeof().sure().unify(output);
        var inMatchesArray = (macro new Array()).typeof().sure().unify(input);

        if (debug) {
            trace( 'IN unify []     :   ' + inMatchesArray );
            trace( 'OUT unify []    :   ' + outMatchesArray );
        }
        
        // Ouput expects an array, so just wrap the value. `[value]`.
        if (outMatchesArray && !inMatchesArray) {
            // Switch into the Array `<T>` type and fetch its type parameter.
            switch output {
                case TInst(_, [t1]):
                    if (debug) trace( '[] `<T>`    :   ' + t1 );

                    switch convertValue(input, t1.follow(), value) {
                        case Success(r): 
                            return Success( macro @:pos(pos) [$r] );

                        case Failure(e): 
                            error = e;

                    }

                case x:
                    if (debug) trace( x );

            }

        } 
        
        // Map an array. `array1.map( valueIn -> valueOut )`
        if (inMatchesArray && outMatchesArray) {
            if (debug) trace( '---map arrays---' );
            var t1 = input;
            var t2 = output;
            // Get each arrays `<T>` type.
            switch input {
                case TInst(_, [t]): t1 = t.follow();
                case x: if (debug) trace( x );
            }

            switch output {
                case TInst(_, [t]): t2 = t.follow();
                case x: if (debug) trace( x );
            }

            /**
                Get the expr needed to convert from one type to another.
                Use `macro v` as the expr, as the mapping happens after this, if successful.
            **/
            switch convertValue(t1, t2, macro v) {
                case Success(r): return Success( macro @:pos(pos) $value.map(v->$r) );
                case Failure(e): error = e;
            }

        }

        // Fallback to looking up a function.
        var inputComplex = input.toComplexType();
        var signature = (macro:$inputComplex->$outputComplex).toType().sure();

        if (debug) {
            trace( 'input ctype     :   ' + inputComplex.toString() );
            trace( 'output ctype    :   ' + outputComplex.toString() );
            trace( 'sig             :   ' + signature );
        }

        var tmp:Expr = null;

        switch findMethod(signature, output, true, pos) {
            case Success(matches):
                if (matches.length == 1) {
                    tmp = outputID.resolve().field( matches[0].name );

                } else if (matches.length > 1) {
                    while (matches.length > 1) {
                        var field = matches.pop();

                        if (field.type.unify(signature)) {
                            tmp = outputID.resolve().field( field.name );
                            break;

                        }

                    }

                } else {
                    error = new Error( NotFound, NoMatches, pos );

                }

            case Failure(err):
                error = err;

        };

        if (error != null) return Failure(error);
        
        return Success( tmp == null ? value : macro @:pos(pos) $tmp($value) );
    }

    public static function handleTask(task:ResolveTask, ?debug:Bool):Expr {
        if (debug == null) debug = Debug && ResolveVerbose;
        var result:Expr = null;
        var pos = Context.currentPos();

        switch task {
            // Multiple is a mess still.
            case Multiple(tasks):
                var names:Array<String> = [];
                var methods:Array<{name:String, type:Type, meta:Metadata, hits:Array<{sig:Type, expr:Expr}>}> = [];
                
                for (task in tasks) switch task {
                    case Multiple(tasks):
                        Context.fatalError( NoNesting, pos );

                    case SearchProperty(signture, module, statics, expr, ereg, meta):
                        Context.fatalError( 'Searching multiple properties is not supported yet.', pos );

                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                        if (debug) trace( 'multi task  :   search methods' );
                        switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                            case Success(matches):
                                if (matches.length == 0) continue;
                                if (debug) trace( 'matches     :   ' + matches.map( m -> m.name ) );

                                for (match in matches) {
                                    var idx = names.indexOf(match.name);

                                    if (idx == -1) {
                                        names.push( match.name );
                                        methods.push(
                                            { name:match.name, type:match.type, meta:match.meta, hits:[ {sig:signature, expr:e} ] }
                                        );

                                    } else {
                                        methods[idx].hits.push( {sig:signature, expr:e} );

                                    }

                                }
        
                            case Failure(error):
                                Context.fatalError( error.message, error.pos );
        
                        };

                    case x:
                        Context.fatalError( 'Not implemented: $x', pos );

                }

                var matches = [for (_ => obj in methods) obj];
                haxe.ds.ArraySort.sort(matches, (a, b) -> a.hits.length - b.hits.length );

                if (debug) trace( 'matches     :   ' + matches.map( m -> m.name + ':' + m.hits.length) );

                if (matches.length == 1) {
                    var field = matches[0];
                    result = field.hits[field.hits.length - 1].expr.field( field.name );

                } else if (matches.length > 1) {
                    while (matches.length > 0) {
                        var field = matches.pop();
                        var last = field.hits[field.hits.length - 1];

                        if (debug) {
                            trace( '--checking...--' );
                            trace( 'field name      :   ' + field.name );
                            trace( 'normal type     :   ' + field.type.toString() );
                            trace( 'reduced type    :   ' + field.type.follow().toString() );
                            trace( 'last hit sig    :   ' + last.sig.toString() );
                        }

                        if (field.type.follow().unify(last.sig)) {
                            if (debug) {
                                trace( '<--unified-->' );
                                trace( 'field name  :   ' + field.name );
                                trace( 'last expr   :   ' + last.expr.toString() );
                            }
                            result = last.expr.field( field.name );

                            /**
                                This means an instance/reference to an Abstract was passed in,
                                and a static field was matched, requiring the first arg to the ref.
                            **/
                            var binder = field.meta.filter( m -> m.name == ResolverBind );
                            if (binder.length != 0) {
                                var expr = switch tasks[0] {
                                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg): e;
                                    case _: null;
                                }

                                var args = [macro $e{expr}];
                                for (i in 0...(Std.parseInt( binder[0].params[0].toString() ))) {
                                    args.push( macro _ );
                                }

                                // I assume the compiler is smart enough to remove the `.bind`
                                result = macro $e{result}.bind($a{args});
                            }

                            break;

                        } else {
                            if (debug) {
                                trace('<--mismatch-->');
                                trace( 'field name  :   ' + field.name );
                            }

                        }

                    }

                } else {
                    Context.fatalError( NoMatches, pos );

                }

                if (debug) trace( 'multi result:   ' + result.toString() );

            case ConvertValue(input, output, value): 
                switch Resolver.convertValue(input, output, value) {
                    case Success(expr): 
                        result = expr;

                    case Failure(error): 
                        Context.fatalError( error.message, error.pos );
                        
                };

            case SearchProperty(signature, module, statics, e, fieldEReg, metaEReg):
                switch Resolver.findProperty(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                    case Success(matches):
                        if (matches.length == 1) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 1) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (debug) {
                                    trace( '<checking ...>' );
                                    trace( 'field name      :   ' + field.name );
                                    trace( 'normal type     :   ' + field.type );
                                    trace( 'reduced type    :   ' + field.type.follow() );
                                    trace( 'signature       :   ' + signature );
                                }

                                if (field.type.follow().unify(signature)) {
                                    result = e.field( field.name );
                                    break;

                                } else {
                                    if (debug) {
                                        trace( 'Field `' + field.name + '` type ' + field.type + ' failed to match against ' + signature );
                                    }
                                    result = e.field( field.name );

                                }

                            }

                        } else if (signature.unify(module)) {
                            // Compatible types should just pass thru.
                            result = e;

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                }

            case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                    case Success(matches):
                        if (matches.length == 1) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 1) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (debug) {
                                    trace( '--checking...--' );
                                    trace( 'field name      :   ' + field.name );
                                    trace( 'normal type     :   ' + field.type );
                                    trace( 'reduced type    :   ' + field.type.follow() );
                                    trace( 'signature       :   ' + signature );
                                }

                                if (field.type.follow().unify(signature)) {
                                    result = e.field( field.name );
                                    break;

                                } else {
                                    if (debug) {
                                        trace( 'Field `' + field.name + '` type ' + field.type + ' failed to match against ' + signature );
                                    }

                                }

                            }

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                };

        }

        if (result == null) {
            Context.fatalError( TotalFailure, pos );

        }

        return result;
    }

}