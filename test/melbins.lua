require 'audio'
require 'gnuplot'
require 'xlua'
fftfreq = audio.fftfreq(200, 1/8000)
binmat = audio.melbins(200, 1/8000, 40)

ptab={}
for i=1,binmat:size(1) do
   _, ix = torch.max(binmat,2)
   print("filter " .. i .. " peak:" .. fftfreq[ix[i][1]] .. 'Hz')
   ptab[#ptab+1] = {fftfreq,binmat[i],'-'}
end
gnuplot.plot(ptab)
