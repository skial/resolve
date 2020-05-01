package be.coerce;

@:notNull @:forward @:forwardStatics enum abstract Metadata(String) from String to String {
    public var CoreApi = ':coreApi';
    public var CoreType = ':coreType';
}