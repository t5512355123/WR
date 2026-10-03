struct test_command { const char *name; int (*exec)(const char **); };
#define DEFINE_WRC_COMMAND(name) const struct test_command test_command_##name
int sub_cmd(const char *const *, unsigned, const char **);
