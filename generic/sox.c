#ifndef TH_GENERIC_FILE
#define TH_GENERIC_FILE "generic/sox.c"
#else

#define check(x) do if (!(x)) { \
  fprintf(stderr, "check failed: %s\n", #x); goto error; } while (0)
#define BUFSIZE 1024

/* ---------------------------------------------------------------------- */
/* -- */
/* -- Copyright (c) 2012 Soumith Chintala */
/* --  */
/* -- Permission is hereby granted, free of charge, to any person obtaining */
/* -- a copy of this software and associated documentation files (the */
/* -- "Software"), to deal in the Software without restriction, including */
/* -- without limitation the rights to use, copy, modify, merge, publish, */
/* -- distribute, sublicense, and/or sell copies of the Software, and to */
/* -- permit persons to whom the Software is furnished to do so, subject to */
/* -- the following conditions: */
/* --  */
/* -- The above copyright notice and this permission notice shall be */
/* -- included in all copies or substantial portions of the Software. */
/* --  */
/* -- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, */
/* -- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF */
/* -- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND */
/* -- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE */
/* -- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION */
/* -- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION */
/* -- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
/* --  */
/* ---------------------------------------------------------------------- */
/* -- description: */
/* --     sox.c - a wrapper from libSox to Torch-7 */
/* -- */
/* -- history:  */
/* --     May 24th, 2012, 8:38PM - wrote load function - Soumith Chintala */
/* ---------------------------------------------------------------------- */

static THTensor * libsox_(read_audio_fileSND)(const char *file_name)
{
  THTensor *tensor;
	SNDFILE	 	*infile = NULL ;
	SF_INFO	 	sfinfo ;
  int readcount;
  int* buf;
  real *tensor_data ;
  check(infile = sf_open(file_name, SFM_READ, &sfinfo));
  printf("channels %d, sample rate %d, samples %d\n", sfinfo.channels, sfinfo.samplerate, sfinfo.frames);
  check(buf = malloc(sizeof(int) * sfinfo.frames * sfinfo.channels));
  check(sf_readf_int(infile, buf, sfinfo.frames) == sfinfo.frames);

  tensor      = THTensor_(newWithSize2d)(sfinfo.channels, sfinfo.frames);
  tensor      = THTensor_(newContiguous)(tensor);
  tensor_data = THTensor_(data)(tensor);
  // convert audio to dest tensor 
	int k, m;
  for (k = 0 ; k < sfinfo.frames ; k++) {	
    for (m = 0 ; m < sfinfo.channels ; m++) {
      tensor_data[m*sfinfo.frames + k] = (real)buf[k * sfinfo.channels + m];
    }
  }

  // cleanup
  sf_close(infile);
  free(buf);
  THTensor_(free)(tensor);
  return tensor;
error:
  sf_close(infile);
  free(buf);
  tensor = THTensor_(new)();
  return tensor;
}

static THTensor * libsox_(read_audio_file2)(const char *file_name)
{
  sox_format_t * in;
  sox_sample_t * buf;
  size_t bufsize, samples_read;
  THTensor *tensor;

  check(in = sox_open_read(file_name, NULL, NULL, NULL));
  /*check(sox_seek(in, 0, SOX_SEEK_SET) == SOX_SUCCESS);*/
  bufsize = in->signal.length;
  printf("bufsize %d\n", (int)bufsize);
  check(buf = malloc(sizeof(sox_sample_t) * bufsize));
  printf("malloced\n");
  /*samples_read = sox_read(in, buf, bufsize);*/

  free(buf);
  printf("freed\n");
  check(sox_close(in) == SOX_SUCCESS);
  printf("closed\n");
  check(sox_quit());
  printf("quitted\n");

  tensor = THTensor_(newWithSize2d)(10,10);
  return tensor;
error:
  tensor = THTensor_(new)();
  return tensor;
}

static THTensor * libsox_(read_audio_file)(const char *file_name)
{
  THTensor *tensor;
  // Create sox objects and read into int32_t buffer
  sox_format_t *fd;
  /*fd = sox_open_read(file_name, NULL, NULL, "sndfile");*/
  check(fd = sox_open_read(file_name, NULL, NULL, NULL));
  /*fd = malloc(sizeof(sox_format_t));*/
  /*fd->signal.channels=1;*/
  /*fd->signal.length=10000;*/
  printf("opened file %s\n", file_name);
  if (fd == NULL)
    abort_("[read_audio_file] Failure to read file");
  
  int nchannels = fd->signal.channels;
  printf("nchannels %d\n", nchannels);
  long buffer_size = fd->signal.length;
  /*int32_t *buffer = (int32_t *)malloc(sizeof(int32_t) * buffer_size);*/
  sox_sample_t *buffer;
  printf("wanna malloc buffersize %d / sizeof sox_sample_t %d / sizeof int32 %d\n", 
      buffer_size, sizeof(sox_sample_t), sizeof(int32_t));
  /*check(buffer = (sox_sample_t *)malloc(sizeof(sox_sample_t) * buffer_size));*/
  buffer = (sox_sample_t *) malloc(sizeof(sox_sample_t) * buffer_size);
  /*check(buffer = malloc(sizeof(sox_sample_t) * buffer_size));*/
  /*buffer = malloc(sizeof(sox_sample_t) * buffer_size);*/
  size_t samples_read = sox_read(fd, buffer, buffer_size);
  check(samples_read == buffer_size);
  check(samples_read % nchannels == 0);
  if (samples_read == 0)
    abort_("[read_audio_file] Empty file or read failed in sox_read");
  // alloc tensor 
  tensor = THTensor_(newWithSize2d)(nchannels, samples_read / nchannels );
  tensor = THTensor_(newContiguous)(tensor);
  /*THTensor_(fill)(tensor, 1);*/
  real *tensor_data = THTensor_(data)(tensor);
  // convert audio to dest tensor 
  int x,k;
  for (k=0; k<nchannels; k++) {
    for (x=0; x<samples_read/nchannels; x++) {
      *tensor_data++ = (real) 1; //(real)buffer[x*nchannels+k];
    }
  }
  // free buffer and sox structures
  free(buffer);
  sox_close(fd);
  sox_format_quit();
  /*free(fd);*/
  THTensor_(free)(tensor);

  // return tensor 
  return tensor;
error:
  tensor = THTensor_(new)();
  return tensor;
}

static int libsox_(Main_load)(lua_State *L) {
  const char *filename = luaL_checkstring(L, 1);
  THTensor *tensor = libsox_(read_audio_fileSND)(filename);
  luaT_pushudata(L, tensor, torch_Tensor);
  return 1;
}

static const luaL_Reg libsox_(Main__)[] =
{
  {"load", libsox_(Main_load)},
  {NULL, NULL}
};

DLL_EXPORT int libsox_(Main_init)(lua_State *L)
{
  luaT_pushmetatable(L, torch_Tensor);
  luaT_registeratname(L, libsox_(Main__), "libsox");
  /* All libSoX applications must start by initialising the SoX library */
  /*check(sox_format_init() == SOX_SUCCESS);*/
  return 1;
error:
  abort_("couldnt init sox");
}

#endif
