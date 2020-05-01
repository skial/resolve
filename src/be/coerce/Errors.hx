package be.coerce;

@:notNull @:forward @:forwardStatics enum abstract Errors(String) from String to String {
    public var NoMatches = 'No vailid matches have been found.';
    public var UseCoerce = 'Use `Resolve.coerce` instead.';
    public var UseResolve = 'Use `Resolve.resolve` instead.';
    public var NotFunction = 'Signature should be a function.';
    public var TotalFailure = 'No expression can be found or constructed.';
}