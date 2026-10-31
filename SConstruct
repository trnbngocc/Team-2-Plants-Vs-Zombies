env = SConscript("extern/godot-cpp/SConstruct", {"api_version": "4.7"})

env.Append(CPPPATH=["src/"])

sources = Glob("src/*.cpp")

library = env.SharedLibrary(
    "plants-vs-zombies/bin/libpvz{}{}".format(
        env["suffix"], env["SHLIBSUFFIX"]
    ),
    source=sources,
)

Default(library)