test(
    'utilstest',
    executable(
        'utilstest',
        'test.cpp',
        dependencies: [utils_dep, gtest_dep, uuid_dep] + extra_deps + extra_libs,
    ),
    protocol: 'gtest',
)

test(
    'processtest',
    executable(
        'processtest',
        'processtest.cpp',
        dependencies: [utils_dep, gtest_dep] + extra_deps + extra_libs,
    ),
    protocol: 'gtest',
)
