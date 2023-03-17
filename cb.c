// The MIT License (MIT)
//
// Copyright (c) 2023 Sungbae Jeong
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// A building script for AxiomOS
//
// Since this program terminates immediately after all buidings are finished,
// leaking a memory is fine.

#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/unistd.h>

#ifdef _WIN32
#error "Windows is not supported. Use Linux subsystem to compile this"
#else
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#define PANIC(...)                    \
    do {                              \
        fprintf(stderr, __VA_ARGS__); \
        exit(1);                      \
    } while (0)

#define COMMAND_MESSAGE                                   \
    "info: Usage: cb [command] [options]\n"               \
    "\n"                                                  \
    "Commands:\n"                                         \
    "\n"                                                  \
    "    compile         Compile this project.\n"         \
    "    make-iso        Make ISO file of this project\n" \
    "    run-qemu        Run QEMU\n"                      \
    "    clean           Clean object files\n"            \
    "\n"                                                  \
    "Options:\n"                                          \
    "\n"                                                  \
    "  -h, --help        Print command-specific usage\n\n"

// ANSI escape codes
#define RESET_ATTR "\x1b[0m"
#define BOLD_ATTR "\x1b[1m"
#define INFO_ATTR "\x1b[1m\x1b[97m"
#define ERROR_ATTR "\x1b[1m\x1b[91m"

typedef struct {
    const char* cmd_name;
    char* const* argv;
} Command;

const Command* _make_cmd(const char* cmd, ...);
void print_cmd(const Command* cmd);
pid_t run_cmd_async(const Command* cmd);
void run_cmd(const Command* cmd);
void pid_wait(pid_t pid);
bool rebuild_itself(const char* bin_path, char** argv);

void compile_project(void);
void make_iso(void);
void run_qemu(void);
void clean_objs(void);

#define make_cmd(...) _make_cmd(__VA_ARGS__, NULL)

int main(int argc, char** argv) {
    if (rebuild_itself(argv[0], argv)) {
        return 0;
    }

    if (argc < 2) {
        printf(COMMAND_MESSAGE);
        printf(ERROR_ATTR "ERROR:" RESET_ATTR " no command was given\n");
        return 1;
    }

    if (strcmp(argv[1], "compile") == 0) {
        compile_project();
    } else if (strcmp(argv[1], "make-iso") == 0) {
        make_iso();
    } else if (strcmp(argv[1], "run-qemu") == 0) {
        run_qemu();
    } else if (strcmp(argv[1], "clean") == 0) {
        clean_objs();
    } else {
        fprintf(stderr, COMMAND_MESSAGE);
        fprintf(stderr, ERROR_ATTR "ERROR:" RESET_ATTR " unknown subcommand found\n");
        return 1;
    }

    return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

// Definition of building compilers
#define ASM_COMPILER "nasm"

#define C_COMPILER "i686-elf-gcc"
#define C_LINKER "i686-elf-ld"

const char* change_extension(const char* filename, const char* ext);
const char* change_directory(const char* filename, const char* prefix);

#define change_filename(_prefix, _orig, _suffix) \
    (change_directory(change_extension(_orig, _suffix), _prefix))

void compile_project(void) {
    const char* asm_srcs[] = {
        "./src/loader.asm",  //
        NULL,
    };

    run_cmd(make_cmd("mkdir", "-p", "obj"));

    for (size_t i = 0; asm_srcs[i]; ++i) {
        const char* asm_obj = change_filename("./obj", asm_srcs[i], "o");
        const Command* nasm_cmd = make_cmd(ASM_COMPILER, "-felf32", "-o", asm_obj, asm_srcs[i]);
        run_cmd(nasm_cmd);
    }
}

void make_iso(void) {
    PANIC("make_iso is not yet implemented\n");
}

void run_qemu(void) {
    PANIC("run_qemu is not yet implemented\n");
}

////////////////////////////////////////////////////////////////////////////////////////////////////

const Command* _make_cmd(const char* cmd, ...) {
    va_list va;
    size_t argv_len = 2;

    va_start(va, cmd);
    for (;; ++argv_len) {
        const char* tmp = va_arg(va, const char*);
        if (tmp == NULL) {
            break;
        }
    }
    va_end(va);

    Command* output = malloc(sizeof(Command));
    output->cmd_name = cmd;

    char** tmp_argv = malloc(sizeof(char**) * argv_len);
    tmp_argv[0] = (char*)cmd;
    tmp_argv[argv_len - 1] = NULL;

    va_start(va, cmd);
    for (size_t i = 1; i + 1 < argv_len; ++i) {
        const char* str = va_arg(va, const char*);
        size_t str_len = strlen(str);
        tmp_argv[i] = malloc(sizeof(char) * (str_len + 1));
        strncpy(tmp_argv[i], str, str_len);
    }
    va_end(va);

    output->argv = tmp_argv;

    return output;
}

void print_cmd(const Command* cmd) {
    fprintf(stderr, INFO_ATTR "INFO:" RESET_ATTR);
    for (const char** arg = (const char**)cmd->argv; *arg; ++arg) {
        fprintf(stderr, " %s", *arg);
    }
    fprintf(stderr, "\n");
}

pid_t run_cmd_async(const Command* cmd) {
    pid_t pid = fork();
    if (pid < 0) {
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " cannot make a process\n");
    }

    if (pid == 0) {
        if (execvp(cmd->cmd_name, cmd->argv) < 0) {
            PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " cannot execute %s\n", cmd->cmd_name);
        }
    }

    return pid;
}

void run_cmd(const Command* cmd) {
    print_cmd(cmd);
    pid_wait(run_cmd_async(cmd));
}

void pid_wait(pid_t pid) {
    while (true) {
        int wait_stat = 0;
        if (waitpid(pid, &wait_stat, 0) < 0) {
            PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " could not wait pid: %d\n", pid);
        }

        if (WIFEXITED(wait_stat)) {
            int exit_status = WEXITSTATUS(wait_stat);
            if (exit_status != 0) {
                PANIC(ERROR_ATTR "ERROR:" RESET_ATTR
                                 " a child process %d exited with exit code %d\n",
                      pid, exit_status);
            }

            break;
        }

        if (WIFSIGNALED(wait_stat)) {
            PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " command process was terminated by %s\n",
                  strsignal(WTERMSIG(wait_stat)));
        }
    }
}

bool rebuild_itself(const char* bin_path, char** argv) {
    const char* this_file = __FILE__;

    struct stat statbuf;

    stat(this_file, &statbuf);
    size_t file_time_sec = statbuf.st_mtimespec.tv_sec;

    stat(bin_path, &statbuf);
    size_t bin_time_sec = statbuf.st_mtimespec.tv_sec;

    if (file_time_sec > bin_time_sec) {
        const Command* gcc_cmd = make_cmd("gcc", this_file, "-Wall", "-Wextra", "-o", "cb");
        Command bin_cmd = {
            .cmd_name = bin_path,
            .argv = argv,
        };

        run_cmd(gcc_cmd);
        run_cmd(&bin_cmd);

        return true;
    } else {
        return false;
    }
}

void clean_objs(void) {}

////////////////////////////////////////////////////////////////////////////////////////////////////

const char* change_extension(const char* filename, const char* ext) {
    size_t filename_len = strlen(filename);
    size_t ext_len = strlen(ext);
    char* output = malloc(filename_len + ext_len);

    size_t period_location;
    for (period_location = filename_len - 1; period_location > 0; --period_location) {
        if (filename[period_location] == '.') {
            break;
        }
    }
    if (period_location == 0) {
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " Invalid filename was found.\n    filename: %s\n",
              filename);
    }

    strncpy(output, filename, period_location + 1);
    strncpy(output + period_location + 1, ext, ext_len);
    output[period_location + ext_len + 1] = '\0';

    return output;
}

const char* change_directory(const char* filename, const char* prefix) {
    size_t filename_len = strlen(filename);
    size_t prefix_len = strlen(prefix);
    char* output = malloc(filename_len + prefix_len + 1);

    size_t slash_location;
    for (slash_location = filename_len - 1; slash_location > 0; --slash_location) {
        if (filename[slash_location] == '/') {
            break;
        }
    }
    if (slash_location == 0) {
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " Invalid filename was found.\n    filename: %s\n",
              filename);
    }

    strncpy(output, prefix, prefix_len);
    strncpy(output + prefix_len, filename + slash_location, filename_len - slash_location + 1);
    output[prefix_len + filename_len - slash_location + 1] = '\0';

    return output;
}
