package be.types;

#if (eval||macro)
import haxe.macro.*;

using tink.MacroApi;
#end

#if !(eval || macro)
@:genericBuild( be.macros.PickBuilder.search() )
#end
class Pick<Rest> {}