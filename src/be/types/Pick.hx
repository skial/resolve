package be.types;

#if !(eval || macro)
@:genericBuild( be.macros.PickBuilder.search() )
#end
class Pick<Rest> {}