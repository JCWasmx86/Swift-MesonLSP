partial_interpreter_tester = executable(
    'partial-interpreter-tester',
    'partial-interpreter-tester.cpp',
    dependencies: [
        analyze_dep,
        ast_dep,
        log_dep,
        objects_dep,
    ] + extra_deps + extra_libs,
)

type_analyzer_tester = executable(
    'type-analyzer-tester',
    'type-analyzer-tester.cpp',
    dependencies: [
        analyze_dep,
        ast_dep,
        log_dep,
        objects_dep,
    ] + extra_deps + extra_libs,
)

workspace_tester = executable(
    'workspace-tester',
    'workspace-tester.cpp',
    dependencies: [log_dep, langserver_dep] + extra_deps + extra_libs,
)

wrap_tester = executable(
    'wrap-tester',
    'wrap-tester.cpp',
    dependencies: [wrap_dep] + extra_deps + extra_libs,
)

wrap_files = files(
    'wrap-test/libswiftdemangle.wrap',
    'wrap-test/libswiftdemangle2.wrap',
    'wrap-test/miniz.wrap',
    'wrap-test/pango.wrap',
    'wrap-test/pidgin.wrap',
    'wrap-test/rubberband.wrap',
    'wrap-test/rustc-demangle.wrap',
    'wrap-test/sqlite.wrap',
    'wrap-test/turtle.wrap',
    'wrap-test/turtle2.wrap',
    'wrap-test/turtle3.wrap',
    'wrap-test/vorbis.wrap',
)

test('wrap-test', wrap_tester, args: [wrap_files], timeout: 200000)

partial_interpreter_tests = [
    [
        'foreach',
        [
            'have_foo',
            'have_bar',
            'have_baz',
            'foohave_',
            'barhave_',
            'bazhave_',
        ],
    ],
    [
        'format',
        [
            'have_2',
            'have_3',
        ],
    ],
    [
        'underscorify',
        [
            'glib_genmarshal',
            'glib_mkenums',
        ],
    ],
    [
        'harfbuzz',
        [
            'hb_shape_fuzzer_exe',
            'hb_subset_fuzzer_exe',
            'hb_set_fuzzer_exe',
            'hb_draw_fuzzer_exe',
            'hb_repacker_fuzzer_exe',
        ],
    ],
    [
        'gdkpixbuf',
        ['gdk_pixbuf_csource', 'gdk_pixbuf_query_loaders', 'gdk_pixbuf_pixdata'],
    ],
    [
        'vpx8',
        [
            'have_vp8_encoder',
            'have_vp8_decoder',
            'have_vp9_encoder',
            'have_vp9_decoder',
        ],
    ],
    [
        'vpx2',
        [
            'have_vp6_encoder',
            'have_vp6_decoder',
            'have_vp7_encoder',
            'have_vp7_decoder',
        ],
    ],
    [
        'wayland',
        [
            'wayland_client_protocol_h',
            'wayland_server_protocol_h',
            'wayland_client_protocol_core_h',
            'wayland_server_protocol_core_h',
        ],
    ],
    [
        'grilo',
        [
            'bookmarks_enabled',
            'bookmarks_idx',
            'filesystem_enabled',
            'filesystem_idx',
            'lua_factory_enabled',
            'lua_factory_idx',
            'youtube_enabled',
            'youtube_idx',
            'bookmarks_enabledfoo',
            'filesystem_enabledfoo',
            'lua_factory_enabledfoo',
            'youtube_enabledfoo',
        ],
    ],
    ['dict+join_path', ['arch1/x86', 'a/b', 'a1/b', 'arch/x861']],
    [
        'goa',
        [
            'afc',
            'goa',
            'mtp',
        ],
    ],
    [
        'dict+iter',
        [
            'dict11111',
            'dict22222',
        ],
    ],
    [
        'imgui',
        ['python_binding', 'cpp_binding', 'human_binding', 'lua___shim'],
        'imgui-options',
    ],
]

foreach test_data : partial_interpreter_tests
    file = files('partial-interpreter-test' / (test_data[0] + '.meson'))[0]
    options_file = (
        test_data.length() == 2 ? [] : (
            ['--'] + files(
                'partial-interpreter-test' / (test_data[2] + '.meson'),
            )
        )
    )

    test(
        'pt-' + test_data[0],
        partial_interpreter_tester,
        args: [file] + test_data[1] + options_file,
    )
endforeach


type_analyzer_tests = [
    [
        'basictests',
        [
            ['conditional', 'int|str'],
            ['somestr', 'str'],
            ['someint', 'int'],
            ['somebool', 'bool'],
            ['someemptydict', 'dict()'],
            ['somedict', 'dict(int|str)'],
            ['someemptyarray', 'list()'],
            ['somearray', 'list(int|str)'],
            ['mixedbagiter', 'dict()|int|list()|meson|str'],
            ['dictkey', 'str'],
            ['dictvalue', 'int|list(dict()|int|list()|meson|str)'],
            ['firstmixedbagiter', 'dict()|int|list()|meson|str'],
            ['somedictvalue', 'int|str'],
            ['somesubstr', 'str'],
            ['custom_idx', 'custom_idx'],

            # Builtins
            ['meson', 'meson'],
            ['build_machine', 'build_machine'],
            ['host_machine', 'host_machine'],
            ['target_machine', 'target_machine'],
        ],
    ],
    [
        'options',
        [
            ['strvalue', 'str'],
            ['boolvalue', 'bool'],
            ['combovalue', 'str'],
            ['intvalue', 'int'],
            ['arrayvalue', 'list(str)'],
            ['featurevalue', 'feature'],
            ['int_and_strvalue', 'int|str'],
            ['unknownvalue', 'bool|feature|int|list(bool|int|str)|str'],
        ],
        'options_options',
    ],
    [
        'build_target',
        [
            ['executable', 'exe'],
            ['shared_library', 'lib'],
            ['static_library', 'lib'],
            ['library', 'lib'],
            ['shared_module', 'build_tgt'],
            ['both_libraries', 'both_libs'],
            ['jar', 'jar'],
            ['conditional', 'jar|lib'],
        ],
    ],
    [
        'binaryexpression',
        [
            ['bool_and', 'bool'],
            ['bool_or', 'bool'],
            ['int_div', 'int'],
            ['str_div', 'str'],
            ['int_eq', 'bool'],
            ['object_eq', 'bool'],
            ['list_neq', 'bool'],
            ['int_ge', 'bool'],
            ['int_gt', 'bool'],
            ['int_le', 'bool'],
            ['int_lt', 'bool'],
            ['in_check', 'bool'],
            ['not_in_check', 'bool'],
            ['int_minus', 'int'],
            ['int_mod', 'int'],
            ['int_mul', 'int'],
            ['str_plus', 'str'],
            ['int_plus', 'int'],
            ['list_list_plus', 'list(int|list(str)|str)'],
            ['list_other_plus', 'list(int|str)'],
            ['dict_dict_plus', 'dict(build_machine|int|meson)'],
        ],
    ],
    [
        'selectionstatement',
        [['full', 'bool|dict(int)|host_machine|list()|meson|target_machine']],
    ],
    [
        'assignment',
        [
            ['someint', 'int'],
            ['somestr', 'str'],
            ['somelist', 'list(int|str)'],
            ['somelist2', 'list(bool|int|str)'],
            ['someint2', 'int'],
            ['somestr2', 'str'],
            ['somebool', 'bool'],
            ['somebool2', 'bool'],
            ['someunaryint', 'int'],
        ],
    ],
    [
        'get_method_improved',
        [
            ['somelist', 'list(bool|dict(bool|int)|list(int))'],
            ['somelist_sub_no_default', 'any|dict(any)|list(any)'],
            ['somelist_sub', 'any|dict(any)|list(any|int)'],
            ['somelist_sub2', 'any|dict(any|bool|int)|list(any)'],
            ['somedict', 'dict(bool|dict(int)|int|list(int))'],
            ['somedict_sub_no_default', 'any|dict(any)|list(any)'],
            ['somedict_sub', 'any|dict(any)|list(any|int)'],
            ['somedict_sub2', 'any|dict(any|int)|list(any)'],
        ],
    ],
]

foreach test_data : type_analyzer_tests
    file = files('type-analyzer-test' / (test_data[0] + '.meson'))[0]
    options_file = (
        test_data.length() == 2 ? [] : (
            ['--'] + files(
                'type-analyzer-test' / (test_data[2] + '.meson'),
            )
        )
    )

    test(
        'ta-' + test_data[0],
        type_analyzer_tester,
        args: [file] + test_data[1] + options_file,
    )
endforeach


test(
    'workspace-tester',
    workspace_tester,
    args: files('workspace-test/meson.build'),
)
