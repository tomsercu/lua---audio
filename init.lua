----------------------------------------------------------------------
--
-- Copyright (c) 2012 Soumith Chintala
-- 
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
-- 
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- 
----------------------------------------------------------------------
-- description:
--     audio - an audio toolBox, for Torch
--
-- history: 
--     May 24th, 2012, 7:28PM - wrote sox wrappers - Soumith Chintala
----------------------------------------------------------------------

require 'torch'
require 'sys'
require 'xlua'
require 'dok'
require 'libaudio'

----------------------------------------------------------------------
-- load from multiple formats
--
local function load(filename)
   if not filename then
      print(dok.usage('audio.load',
                       'loads an audio file into a torch.Tensor', nil,
                       {type='string', help='path to file', req=true}))
      dok.error('missing file name', 'audio.load')
   end
   if not paths.filep(filename) then
      dok.error('Specified filename: ' .. filename .. ' not found', 'audio.load')
   end
   local tensor
   if not xlua.require 'libsox' then
      dok.error('libsox package not found, please install libsox','audio.load')
   end
   local a = torch.Tensor().libsox.load(filename)
   return a
end
rawset(audio, 'load', load)

----------------------------------------------------------------------
-- spectrogram
--
local function spectrogram(...)
   local output, input, window_size, window_type, stride
   local args = {...}
   if select('#',...) == 4 then
      input = args[1]
      window_size = args[2]
      window_type = args[3]
      stride = args[4]
   else
      print(dok.usage('audio.spectrogram',
                       'generate the spectrogram of an audio. returns a 2D tensor, with number_of_windows x window_size/2+1, each value representing the magnitude of each frequency in dB', nil,
                       {type='torch.Tensor', help='input single-channel audio', req=true},
                       {type='number', help='window size', req=true},
                       {type='string', help='window type: rect, hamming, hann, bartlett' , req=true},
                       {type='number', help='stride', req=true}))
      dok.error('incorrect arguments', 'audio.spectrogram')
   end

   -- calculate stft
   local stftout = audio.stft(input, window_size, window_type, stride)
   -- torch.Tensor().audio.stft(input, window_size, window_type_id, stride)

   -- calculate magnitude of signal and convert to dB to make it look prettier
   local stftout_r = stftout:select(3,1)
   local stftout_c = stftout:select(3,2)
   stftout_r:pow(2)
   stftout_c:pow(2)
   local stftout_magnitude = stftout_r + stftout_c
   stftout_magnitude = stftout_magnitude + 0.01 -- adding constant to avoid log(0)
   output = stftout_magnitude:log() * 10
   return output:transpose(1,2)
end
rawset(audio, 'spectrogram', spectrogram)

local function stft(...)
   local output, input, window_size, window_type, stride
   local args = {...}
   if select('#',...) == 4 then
      input = args[1]
      window_size = args[2]
      window_type = args[3]
      stride = args[4]
   else
      print(dok.usage('audio.stft',
                       'calculate the stft of an audio. returns a 3D tensor, with number_of_windows x window_size/2+1 x 2(complex number with real and complex parts)', nil,
                       {type='torch.Tensor', help='input single-channel audio', req=true},
                       {type='number', help='window size', req=true},
                       {type='string', help='window type: rect, hamming, hann, bartlett' , req=true},
                       {type='number', help='stride', req=true}))
      dok.error('incorrect arguments', 'audio.stft')
   end
   local window_type_id;
   if window_type == 'rect' then
      window_type_id = 1
   elseif window_type == 'hamming' then
      window_type_id = 2
   elseif window_type == 'hann' then
      window_type_id = 3
   elseif window_type == 'bartlett' then
      window_type_id = 4
   end
   -- calculate stft
   output = torch.Tensor().audio.stft(input, window_size, window_type_id, stride)
   return output
end
rawset(audio, 'stft', stft)

local function cqt(...)
   local output, input, fmin, fmax, bins_per_octave, sample_rate
   local args = {...}
   if select('#',...) == 5 then
      input = args[1]
      fmin = args[2]
      fmax = args[3]
      bins_per_octave = args[3]
      sample_rate = args[4]
   else
      print(dok.usage('audio.cqt',
		      'calculate the constant-Q transformed audio signal. returns a [TODO: fill this description]', nil,
		      {type='torch.Tensor', help='input single-channel audio', req=true},
		      {type='number', help='lowest frequency of interest', req=true},
		      {type='number', help='highest frequency of interest', req=true},
		      {type='number', help='frequency bins per octave', req=true},
		      {type='number', help='sampling rate of the input', req=true}))
      dok.error('incorrect arguments', 'audio.cqt')
   end
   -- calculate stft
   output = torch.Tensor().audio.cqt(input, fmin, fmax, bins_per_octave, sample_rate)
   return output
end
rawset(audio, 'cqt', cqt)


----------------------------------------------------------------------
-- loads voice.mp3 that is included with the repo
local function samplevoice()
   local fname = 'voice.mp3'
   local voice = audio.load(sys.concat(sys.fpath(), fname))   
   return voice
end
rawset(audio, 'samplevoice', samplevoice)

---
local function fftfreq(...)
   local window_size, samplespacing
   local args = {...}
   if select('#',...) == 2 then
      window_size = args[1]
      samplespacing = args[2]
   else
      print(dok.usage('audio.fftfreq',
		      'compute the stft sample frequencies: [0, 1, ... , n/2] / (d*n)', nil,
		      {type='number', help='n = window size of stft or spectrogram', req=true},
		      {type='number', help='d = samplespacing = 1 / (sampling rate)', req=true}))
      dok.error('incorrect arguments', 'audio.fftfreq')
   end
   local output = torch.range(0,window_size/2):mul(1./(window_size * samplespacing))
   return output
end
rawset(audio, 'fftfreq', fftfreq)

---
local function melbins(...)
   local fft_window_size, fft_samplespacing, nbins
   local args = {...}
   if select('#',...) == 3 then
      window_size   = args[1]
      samplespacing = args[2]
      nbins         = args[3]
   else
      print(dok.usage('audio.melbins',
		      'returns the weights matrix that maps the powers of the stft spectrum to the mel scale using triangular windows', nil,
		      {type='number', help='n = window size of fft or spectrogram', req=true},
		      {type='number', help='d = samplespacing = 1 / (sampling rate)', req=true},
		      {type='number', help='nbins = number of mel bins', req=true}))
      dok.error('incorrect arguments', 'audio.melbins')
   end
   local fftfreq = audio.fftfreq(window_size, samplespacing)
   local weights = torch.Tensor(nbins, fftfreq:size(1)):zero()
   local function B(f) return torch.log(f/700 + 1) * 1125 end
   local function Binv(m) return (torch.exp(m/1125) - 1) * 700 end
   local Fs = 1/samplespacing
   local N = fftfreq:size(1)
   local Blo, Bhi = B(fftfreq[1]), B(fftfreq[-1])
   local boundaries = {}
   for m = 0,nbins+1 do
      local boundaryfreq = Binv(Blo + m * (Bhi-Blo)/(nbins+1))
      --boundaries[m] = math.floor(window_size*samplespacing*boundaryfreq + 0.5) -- round to nearest freq
      boundaries[m] = window_size*samplespacing*boundaryfreq -- do not round to nearest freq
      --print(m,boundaryfreq,boundaries[m])
   end
   for m =  1,nbins do
      for k,fk in ipairs(fftfreq:storage():totable()) do
         if (k-1 >= boundaries[m-1]) and (k-1 <= boundaries[m]) then
            weights[{m,k}] = (k-1-boundaries[m-1]) / (boundaries[m] - boundaries[m-1])
         elseif (k-1 >= boundaries[m]) and (k-1 <= boundaries[m+1]) then
            weights[{m,k}] = (boundaries[m+1] - (k-1)) / (boundaries[m+1] - boundaries[m])
         end
      end
   end
   return weights
end
rawset(audio, 'melbins', melbins)
