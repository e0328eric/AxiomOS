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
// since this is a build script, the program of it terminates immediately
// after all build tasks are finished. So, leaking some memories is fine.
// (OS will take care of)
//

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

#define COMMAND_MESSAGE                                               \
    "info: Usage: cb [command] [options]\n"                           \
    "\n"                                                              \
    "Commands:\n"                                                     \
    "\n"                                                              \
    "    compile         Compile this project.\n"                     \
    "    make-iso        Make ISO file of this project\n"             \
    "    run-qemu        Run QEMU\n"                                  \
    "    all             Process (compile -> make-iso -> run_qemu)\n" \
    "    clean           Clean object files\n"                        \
    "\n\n"

// Definition of building compilers
#ifndef ASSEMBLER
#define ASSEMBLER "nasm"
#endif

#ifndef HOST_C_COMPILER
#define HOST_C_COMPILER "gcc"
#endif

#ifndef PROJECT_C_COMPILER
#define PROJECT_C_COMPILER "x86_64-elf-gcc"
#endif

#define PROJECT_C_COMPILER_OPTIONS "-std=gnu11 -Wall -Wextra -Wpedantic"

#define PROJECT_LINKER "x86_64-elf-ld"
#define LINKER_SCRIPT "linker.ld"

#define KERNEL_BIN "kernel.bin"
#define AXIOM_OS_ISO "AxiomOS.iso"

#define OBJECT_HEAD_DIRECTORY "./obj"

// ANSI escape codes
#define RESET_ATTR "\x1b[0m"
#define BOLD_ATTR "\x1b[1m"
#define INFO_ATTR "\x1b[1m\x1b[97m"
#define ERROR_ATTR "\x1b[1m\x1b[91m"

typedef struct {
    const char* cmd_name;
    char* const* argv;
} Command;

char* const* _make_argv(int dummy, ...);
Command* _make_cmd(int dummy, ...);
Command* copy_cmd(const char* cmd_name, char* const* argv);
void free_cmd(const Command* cmd);
Command* append_cmd(Command** prev, char* const* to_append);
void print_cmd(const Command* cmd);
pid_t run_cmd_async(const Command* cmd);
void run_cmd(const Command* cmd);
void pid_wait(pid_t pid);
size_t arraylen(void** array);  // length of an array including NULL
void free_array(void** array);

bool rebuild_itself(const char* bin_path, char** argv);
void compile_project(void);
void make_iso(void);
void run_qemu(void);
void clean_objs(void);

#define MAKE_ARGV(...) _make_argv(1, __VA_ARGS__, NULL)
#define MAKE_CMD(...) _make_cmd(1, __VA_ARGS__, NULL)

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
    } else if (strcmp(argv[1], "all") == 0) {
        compile_project();
        make_iso();
        run_qemu();
    } else {
        fprintf(stderr, COMMAND_MESSAGE);
        fprintf(stderr, ERROR_ATTR "ERROR:" RESET_ATTR " unknown subcommand found\n");
        return 1;
    }

    return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

const char* change_extension(const char* filename, const char* ext);
const char* change_prefix(const char* filename, const char* prefix);
const char* change_filename(const char* prefix, const char* filename, const char* suffix);

const char** compile_assembly(const char** asm_srcs);
const char** compile_c(const char** c_srcs);

void compile_project(void) {
    const char* asm_srcs[] = {
        "./src/bootloader/multiboot_header.asm",  //
        "./src/bootloader/boot.asm",              //
        NULL,
    };

    run_cmd(MAKE_CMD("mkdir", "-p", OBJECT_HEAD_DIRECTORY));
    const char** asm_objs = compile_assembly(asm_srcs);

    Command* asm_link_cmd = MAKE_CMD(PROJECT_LINKER, "-n", "-T", LINKER_SCRIPT);
    Command* tmp = append_cmd(&asm_link_cmd, (char* const*)asm_objs);
    asm_link_cmd = append_cmd(&tmp, MAKE_ARGV("-o", KERNEL_BIN));
    run_cmd(asm_link_cmd);
}

const char** compile_assembly(const char** asm_srcs) {
    size_t asm_srcs_len = arraylen((void**)asm_srcs);
    const char** output = malloc(sizeof(const char*) * asm_srcs_len);
    output[asm_srcs_len - 1] = NULL;

    for (size_t i = 0; i + 1 < asm_srcs_len; ++i) {
        output[i] = change_filename(OBJECT_HEAD_DIRECTORY, asm_srcs[i], "o");
        run_cmd(MAKE_CMD(ASSEMBLER, "-felf64", "-o", output[i], asm_srcs[i]));
    }

    return output;
}

const char** compile_c(const char** c_srcs) {
    size_t c_srcs_len = arraylen((void**)c_srcs);
    const char** output = malloc(sizeof(const char*) * c_srcs_len);
    output[c_srcs_len - 1] = NULL;

    for (size_t i = 0; i + 1 < c_srcs_len; ++i) {
        output[i] = change_filename(OBJECT_HEAD_DIRECTORY, c_srcs[i], "o");
        run_cmd(
            MAKE_CMD(PROJECT_C_COMPILER, PROJECT_C_COMPILER_OPTIONS, "-o", output[i], c_srcs[i]));
    }

    return output;
}

void make_iso(void) {
    run_cmd(MAKE_CMD("mkdir", "-p", "iso/boot/grub"));
    run_cmd(MAKE_CMD("cp", KERNEL_BIN, "iso/boot"));

    FILE* grub_cfg = fopen("iso/boot/grub/grub.cfg", "w");
    if (grub_cfg == NULL) {
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " cannot create a file `iso/boot/grub/grub.cfg`\n");
    }
    const char* menu_lst_content =
        "set timeout=0\n"
        "set default=0\n"
        "\n"
        "menuentry \"AxiomOS\" {\n"
        "    multiboot2 /boot/kernel.bin\n"
        "    boot\n"
        "}\n";
    if (fputs(menu_lst_content, grub_cfg) == EOF) {
        fclose(grub_cfg);
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR
                         " cannot write a content to the file `iso/boot/grub/grub.cfg`\n");
    }

    fclose(grub_cfg);

    run_cmd(MAKE_CMD("grub-mkrescue", "-o", AXIOM_OS_ISO, "iso"));
}

void run_qemu(void) {
    run_cmd(MAKE_CMD("qemu-system-x86_64", "-cdrom", AXIOM_OS_ISO));
}

void clean_objs(void) {
    run_cmd(MAKE_CMD("/bin/rm", "-rf", OBJECT_HEAD_DIRECTORY));
    run_cmd(MAKE_CMD("/bin/rm", "-rf", "./iso"));
    run_cmd(MAKE_CMD("/bin/rm", "-rf", KERNEL_BIN));
    run_cmd(MAKE_CMD("/bin/rm", "-rf", AXIOM_OS_ISO));
}

////////////////////////////////////////////////////////////////////////////////////////////////////

char* const* _make_argv(int dummy, ...) {
    va_list va;
    size_t argv_len = 1;

    va_start(va, dummy);
    for (;; ++argv_len) {
        const char* tmp = va_arg(va, const char*);
        if (tmp == NULL) {
            break;
        }
    }
    va_end(va);

    char** output = malloc(sizeof(char**) * argv_len);
    output[argv_len - 1] = NULL;

    va_start(va, dummy);
    for (size_t i = 0; i + 1 < argv_len; ++i) {
        const char* str = va_arg(va, const char*);
        size_t str_len = strlen(str);
        output[i] = malloc(sizeof(char) * (str_len + 1));
        strncpy(output[i], str, str_len);
    }
    va_end(va);

    return (char* const*)output;
}

Command* _make_cmd(int dummy, ...) {
    va_list va;
    size_t argv_len = 1;

    va_start(va, dummy);
    for (;; ++argv_len) {
        const char* tmp = va_arg(va, const char*);
        if (tmp == NULL) {
            break;
        }
    }
    va_end(va);

    char** tmp_argv = malloc(sizeof(char**) * argv_len);
    tmp_argv[argv_len - 1] = NULL;

    va_start(va, dummy);
    for (size_t i = 0; i + 1 < argv_len; ++i) {
        const char* str = va_arg(va, const char*);
        size_t str_len = strlen(str);
        tmp_argv[i] = malloc(sizeof(char) * (str_len + 1));
        strncpy(tmp_argv[i], str, str_len);
    }
    va_end(va);

    Command* output = malloc(sizeof(Command));
    output->cmd_name = tmp_argv[0];
    output->argv = tmp_argv;

    return output;
}

Command* copy_cmd(const char* cmd_name, char* const* argv) {
    size_t argv_len = arraylen((void**)argv);
    char** tmp_argv = malloc(sizeof(char**) * argv_len);
    tmp_argv[argv_len - 1] = NULL;

    for (size_t i = 0; i + 1 < argv_len; ++i) {
        size_t str_len = strlen(argv[i]);
        tmp_argv[i] = malloc(sizeof(char) * (str_len + 1));
        strncpy(tmp_argv[i], argv[i], str_len);
    }

    Command* output = malloc(sizeof(Command));
    output->cmd_name = cmd_name;
    output->argv = tmp_argv;

    return output;
}

Command* append_cmd(Command** prev, char* const* to_append) {
    size_t prev_argv_len = arraylen((void**)(*prev)->argv);
    size_t to_append_len = arraylen((void**)to_append);
    size_t total_len = prev_argv_len + to_append_len - 1;

    Command* output = malloc(sizeof(Command));
    output->argv = malloc(sizeof(char* const) * total_len);
    memcpy((void*)output->argv, (*prev)->argv, sizeof(char* const) * (prev_argv_len - 1));
    memcpy((void*)(output->argv + prev_argv_len - 1), to_append,
           sizeof(char* const) * to_append_len);

    output->cmd_name = output->argv[0];

    free((void*)(*prev)->argv);
    free((void*)(*prev));
    *prev = NULL;

    return output;
}

void free_cmd(const Command* cmd) {
    if (!cmd) {
        return;
    }

    char* const* ptr = cmd->argv;
    for (const char* arg = *ptr; arg; arg = *++ptr) {
        free((void*)arg);
    }
    free((void*)cmd->argv);
    free((void*)cmd);
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
        free_cmd(cmd);
        PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " cannot make a process\n");
    }

    if (pid == 0) {
        if (execvp(cmd->cmd_name, cmd->argv) < 0) {
            free_cmd(cmd);
            PANIC(ERROR_ATTR "ERROR:" RESET_ATTR " cannot execute %s\n", cmd->cmd_name);
        }
    }

    free_cmd(cmd);
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
        const Command* gcc_cmd =
            MAKE_CMD(HOST_C_COMPILER, this_file, "-Wall", "-Wextra", "-o", "cb");
        const Command* bin_cmd = copy_cmd(bin_path, argv);

        run_cmd(gcc_cmd);
        run_cmd(bin_cmd);

        return true;
    } else {
        return false;
    }
}

size_t arraylen(void** array) {
    size_t output = 1;
    while (array[output - 1]) {
        ++output;
    }

    return output;
}

void free_array(void** array) {
    for (void* ptr = *array; ptr; ptr = *++array) {
        free(ptr);
    }
    free(array);
}

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

const char* change_prefix(const char* filename, const char* prefix) {
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

const char* change_filename(const char* prefix, const char* filename, const char* suffix) {
    const char* add_suffix = change_extension(filename, suffix);
    const char* output = change_prefix(add_suffix, prefix);
    free((void*)add_suffix);

    return output;
}
