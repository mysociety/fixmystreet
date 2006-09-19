/*
 * pnmtilesplit.c:
 * Split a single large PNM file into numerous smaller tiles.
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: pnmtilesplit.c,v 1.10 2006-09-19 11:27:30 chris Exp $";

#include <sys/types.h>

#include <errno.h>
#include <fcntl.h>
#include <pam.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/wait.h>

#define err(...)    \
            do {    \
                fprintf(stderr, "pnmtilesplit: ");  \
                fprintf(stderr, __VA_ARGS__);   \
                fprintf(stderr, "\n");  \
            } while (0)

#define die(...)    do { err(__VA_ARGS__); exit(1); } while (0)

static int verbose;
#define debug(...)  if (verbose) fprintf(stderr, __VA_ARGS__)

/* xmalloc LEN
 * Allocate LEN bytes, returning the allocated buffer on success or dying on
 * failure. */
static void *xmalloc(const size_t s) {
    void *v;
    if (!(v = malloc(s)))
        die("malloc(%u): %s", (unsigned)s, strerror(errno));
    return v;
}

/* open_output_file FORMAT PIPE I J [PID]
 * Open a new output file, constructing it from FORMAT and the column- and
 * row-index values I and J. If PIPE is non-NULL, open the file via a pipe
 * through the shell. Returns a stdio file handle on success or abort on
 * failure. If PIPE is non-NULL then the process ID of the child process is
 * saved in *PID. */
static FILE *open_output_file(const char *fmt, const char *pipe_via,
                                 const int i, const int j, pid_t *child_pid) {
    FILE *fp;
    char *filename;
    filename = xmalloc(strlen(fmt) + 64);
    sprintf(filename, fmt, i, j);
    /* XXX consider creating directories if they don't already exist? */
    if (pipe_via) {
        pid_t p;
        int fd, pp[2];
        if (-1 == (fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0644)))
            die("%s: open: %s", filename, strerror(errno));
        else if (-1 == pipe(pp))
            die("pipe: %s", strerror(errno));
        else if (!(fp = fdopen(pp[1], "w")))
            die("fdopen: %s", strerror(errno));
        
        if (-1 == (p = fork()))
            die("fork: %s", strerror(errno));
        else if (0 == p) {
            /* run the pipe command via /bin/sh */
            char *argv[4] = {"/bin/sh", "-c", 0};
            char si[40], sj[40];
            sprintf(si, "TILECOL=%d", i);
            putenv(si);
            sprintf(sj, "TILEROW=%d", j);
            putenv(sj);
            close(0);
            close(1);
            close(pp[1]);
            dup(pp[0]);     /* standard input */
            close(pp[0]);
            dup(fd);        /* standard output */
            close(fd);
            argv[2] = (char*)pipe_via;
            execv(argv[0], argv);
            err("%s: %s", pipe_via, strerror(errno));
            _exit(1);
        } else if (child_pid)
            *child_pid = p;

        close(pp[0]);
        close(fd);

        debug("forked child process %d for pipe to \"%s\", write fd = %d\n",
                (int)p, filename, pp[1]);
    } else if (!(fp = fopen(filename, "w"))) {
        die("%s: open: %s", filename, strerror(errno));
        debug("opened file \"%s\"\n", filename);
    }

    free(filename);

    return fp;
}

/* usage STREAM
 * Write a usage message to STREAM. */
void usage(FILE *fp) {
    fprintf(fp,
"pnmtilesplit - split a PNM file into fixed-size tiles\n"
"\n"
"Usage: pnmtilesplit -h | [OPTIONS] WIDTH HEIGHT [INPUT]\n"
"\n"
"Split the INPUT image, or, if it is not specified, the image on standard\n"
"input, into WIDTH-by-HEIGHT pixel tiles. If WIDTH or HEIGHT do not divide\n"
"the dimensions of the input image exactly, a warning will be printed and\n"
"the pixels at the extreme right and bottom of the input image will be\n"
"discarded.\n"
"\n"
"Options:\n"
"\n"
"    -h          Display this help message on standard output.\n"
"\n"
"    -v          Output debugging information on standard error.\n"
"\n"
"    -P          Display progress information on standard error (implied by\n"
"                -v).\n"
"\n"
"    -f FORMAT   Use the printf-style FORMAT for the name of the output file,\n"
"                instead of \"%%d,%%d.pnm\".\n"
"\n"
"    -p COMMAND  Don't write files directly, but pipe them via COMMAND. The\n"
"                COMMAND is interpreted by the shell. The variables TILECOL\n"
"                and TILEROW in the environment of the command are set to\n"
"                the column and row indices of the tile being generated.\n"
"\n"
"    -s          Use a slow but more correct implementation, which processes\n"
"                the image files only through netpbm's own API, rather than\n"
"                copying pixel data directly between input and output\n"
"                images.\n"
"\n"
"Note that you can specify -f /dev/null and use the pipe command to create\n"
"the output images, for instance with a command like,\n"
"    pnmtilesplit -p 'pnmtopng > $TILEROW,$TILECOL.png' -f /dev/null 256 256\n"
"if you want to exchange the column and row indices.\n"
"\n"
"Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.\n"
"Email: chris@mysociety.org; WWW: http://www.mysociety.org/\n"
"%s\n",
            rcsid);
}

/* main ARGC ARGV
 * Entry point. */
int main(int argc, char *argv[]) {
    int tile_w, tile_h, cols, rows;
    char *img_name;
    FILE *img_fp, **tile_fp;
    struct pam img_pam, *tile_pam;
    pid_t *tile_pid;
    char *outfile_format = "%d,%d.pnm", *pipe_via = NULL;
    extern int opterr, optopt, optind;
    static const char optstr[] = "hvPsf:p:";
    int i, j, c, progress = 0, fast_and_ugly = 1;
    tuple *img_row = NULL;  /* suppress bogus "might be used uninitialised" */
    unsigned char *buf = NULL;
    size_t img_rowlen = 0, tile_rowlen = 0;

    pnm_init(&argc, argv);
    opterr = 0;

    while (-1 != (c = getopt(argc, argv, optstr))) {
        switch (c) {
            case 'h':
                usage(stdout);
                return 0;

            case 'v':
                verbose = 1;
                /* fall through */

            case 'P':
                progress = 1;
                break;

            case 'f':
                outfile_format = optarg;
                break;

            case 'p':
                pipe_via = optarg;
                break;

            case 's':
                fast_and_ugly = 0;
                break;

            case '?':
            default:
                if (strchr(optstr, optopt))
                    err("option -%c requires an argument", optopt);
                else
                    err("unknown option -%c", optopt);
                die("try -h for help");
        }
    }

    if (argc - optind < 2 || argc - optind > 3) {
        err("two or three non-option arguments required");
        die("try -h for help");
    }

    if (0 == (tile_w = atoi(argv[optind])))
        die("\"%s\" is not a valid tile width", argv[optind]);
    else if (0 == (tile_h = atoi(argv[optind + 1])))
        die("\"%s\" is not a valid tile height", argv[optind + 1]);

    if (argv[optind + 2]) {
        img_name = argv[optind + 2];
        if (!(img_fp = fopen(img_name, "rb"))) {
            die("%s: %s", img_name, strerror(errno));
            return 1;
        }
    } else {
        img_name = "(standard input)";
        img_fp = stdin;
    }

    /* lamely, this will just abort if something goes wrong */
    pnm_readpaminit(img_fp, &img_pam, sizeof img_pam);   
    
    /* couple of checks on the image dimensions */
    if (tile_w > img_pam.width)
        die("image width (%d) is smaller than tile width (%d)",
            img_pam.width, tile_w);
    else if (img_pam.width % tile_w) {
        err("warning: tile width does not divide image width exactly");
        err("warning: last %d columns of image will not be included in any tile",
            img_pam.width % tile_w);
    }
    cols = img_pam.width / tile_w;
    
    if (tile_h > img_pam.height)
        die("image height (%d) is smaller than tile height (%d)",
            img_pam.height, tile_h);
    else if (img_pam.height % tile_h) {
        err("warning: tile height does not divide image height exactly");
        err("warning: last %d rows of image will not be included in any tile",
            img_pam.height % tile_h);
    }
    rows = img_pam.height / tile_h;

    debug("input image is %d by %d pixels\n", img_pam.width, img_pam.height);
    debug(" = %d by %d tiles of %d by %d", cols, rows, tile_w, tile_h);
    debug("each pixel contains %d planes, %d bytes per sample",
            img_pam.depth, img_pam.bytes_per_sample);
 
    tile_fp = xmalloc(cols * sizeof *tile_fp);
    tile_pam = xmalloc(cols * sizeof *tile_pam);
    tile_pid = xmalloc(cols * sizeof *tile_pid);
 
    if (fast_and_ugly) {
        img_rowlen = img_pam.width * img_pam.depth * img_pam.bytes_per_sample;
        buf = xmalloc(img_rowlen);
        tile_rowlen = tile_w * img_pam.depth * img_pam.bytes_per_sample;
    } else if (!(img_row = pnm_allocpamrow(&img_pam)))
        die("unable to allocate storage for input row");
    
    for (j = 0; j < rows; ++j) {
        int y;

        /* Create output files. */
        debug("creating output files for row %d/%d...\n", j, rows);
        for (i = 0; i < cols; ++i) {
            tile_pam[i] = img_pam;
            tile_pam[i].file = tile_fp[i]
                = open_output_file(outfile_format, pipe_via, i, j,
                                    tile_pid + i);
            tile_pam[i].width = tile_w;
            tile_pam[i].height = tile_h;
            pnm_writepaminit(tile_pam + i);
            fflush(tile_fp[i]);
        }

        /* Copy the image into the various tiles. */
        for (y = 0; y < tile_h; ++y) {
            /* Ugly. libpnm is pretty slow, so for large images it is much
             * quicker to copy bytes from input to output streams using
             * straight stdio calls. If fast_and_ugly is true (the default)
             * then we use such an implementation; but it makes assumptions
             * about the format of the input PNM file which might not be
             * accurate. So we make this optional. */
            if (fast_and_ugly) {
                size_t n;
                if (img_rowlen != (n = fread(buf, 1, img_rowlen, img_fp))) {
                    if (feof(img_fp))
                        die("%s: premature EOF", img_name);
                    else
                        die("%s: %s", img_name, strerror(errno));
                }
                for (i = 0; i < cols; ++i) {
                    if (tile_rowlen
                            != (n = fwrite(buf + i * tile_rowlen,
                                            1, tile_rowlen, tile_fp[i]))) {
                        die("while writing tile (%d, %d): %s", i, j,
                            strerror(errno));
                    }
                    fflush(tile_fp[i]);
                }
            } else {
                pnm_readpamrow(&img_pam, img_row);
                for (i = 0; i < cols; ++i) {
                    pnm_writepamrow(tile_pam + i, img_row + i * tile_w);
                    fflush(tile_fp[i]);
                }
            }
            if (progress)
                fprintf(stderr, "\r%d/%d", j * tile_h + y, img_pam.height);
        }

        /* Close the output files and check status. */
        debug("\rclosing output files for row %d/%d...\n", j, rows);
        for (i = 0; i < cols; ++i) {
            debug("closing fd %d... ", fileno(tile_fp[i]));
            if (-1 == fclose(tile_fp[i]))
                die("while writing tile (%d, %d): %s", i, j, strerror(errno));
            debug("done\n");
        }

            /* XXX I think there is a bug here, since if you close fd i, then
             * wait for child process i, the wait hangs. But I can't see the
             * problem at the moment. Actually calling wait synchronously here
             * is bogus anyway, since we could collect the notification when we
             * receive SIGCHLD, though that would risk spawning a vast number
             * of processes; at the moment we maintain as many child processes
             * as there are columns of tiles in the output. */
        if (pipe_via) {
            debug("waiting for termination of child processes\n");
            for (i = 0; i < cols; ++i) {
                /* Collect exit status of child process. */
                pid_t p;
                int st;
                debug("waiting for termination of process %d... ",
                        (int)tile_pid[i]);
                if (-1 == (p = waitpid(tile_pid[i], &st, 0)))
                    die("waitpid: %s", strerror(errno));
                else if (st) {
                    if (WIFEXITED(st))
                        die("child process for tile (%d, %d) failed with "
                            "status %d", i, j, WEXITSTATUS(st));
                    else
                        die("child process for tile (%d, %d) killed by "
                            "signal %d", i, j, WTERMSIG(st));
                }
                debug("exited\n");
            }
        }
    }

    if (progress)
        fprintf(stderr, "\r%d/%d\n", img_pam.height, img_pam.height);
    return 0;
}
