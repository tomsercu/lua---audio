require 'torch'
require 'audio'
torch.setdefaulttensortype('torch.FloatTensor')

fn = 'audio.wav'
foo= audio.load(fn)
print("foo size 2", foo:size(2), "foo min mean max", foo:min(), foo:mean(), foo:max())

a = torch.ones(5,5)
b = torch.Tensor(5,5):fill(1)
fea = torch.mm(a,b)--:log()
print(fea)
