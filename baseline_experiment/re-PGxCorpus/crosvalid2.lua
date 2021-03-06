function f_std(tab, avg)
   local sum = 0
   for i=1,#tab do
      sum = sum + math.pow((tab[i]-avg), 2)
   end
   sum = sum/#tab
   return math.sqrt(sum)
end

require("torch")
require("nn")
require("data")
require("network")
require("nngraph")
require("test")

cmd = torch.CmdLine()

cmd:text()
cmd:text('crosvalid')
cmd:text()
cmd:text()
cmd:text('Misc options:')
cmd:option('-loaddir', '', 'models to load')
cmd:option('-maxnet', 10, 'max number of network to load')
--cmd:option('-minnet', 1, 'max number of network to load')
cmd:option('-optnet', '', 'select networks with a given option')
cmd:option('-hierarchy', false, "consider entity hierarchy at test time")
cmd:text()

torch.setdefaulttensortype('torch.FloatTensor')
math.randomseed(os.time())
torch.manualSeed(os.time())

local params = cmd:parse(arg)
torch.setnumthreads(1)

local cmd = "find " .. params.loaddir .. " -name model-best-valid.bin"
local handle = io.popen (cmd, "r")
print(cmd)


local data, vdata, tdata
local tab_rel = {"isAssociatedWith", "influences", "causes", "increases", "decreases", "treats", "isEquivalentTo"}

local tab_res = {}
for i=1,#tab_rel do
   tab_res[ tab_rel[i] ] = {f1={}, precision={}, recall={}}
end
tab_res.macro = {f1={}, precision={}, recall={}}
tab_res.micro = {f1={}, precision={}, recall={}}


local nbnet = 0
_file = handle:read()
print("----------------------------------------------")
local paramsModel
local nnetwork = 0
while _file and nnetwork<params.maxnet do
   nnetwork = nnetwork + 1
   
   print(_file .. " net n°" .. nnetwork)
   local f = torch.DiskFile(_file):binary()
   paramsModel = f:readObject()

   if nnetwork==1 then
      loadhash(paramsModel)
   end
   
   data = createdata(paramsModel)
   vdata = extract_data(data, paramsModel.validp, paramsModel.valids, true)
   tdata = extract_data(data, paramsModel.validp, paramsModel.valids, true)
   subtraindata = extract_data(data, paramsModel.validp, paramsModel.valids, false)

   if not paramsModel.arch then paramsModel.arch="mccnn" end
   local network = createnetworks(paramsModel,data)
   local net = f:readObject()
   network:loadnet(paramsModel, net)
   
   paramsModel.rundir = params.loaddir .. paramsModel.rundir:match("/([^/]+)$")
   paramsModel.hierarchy = params.hierarchy
   print("================")
   print("tab_res")
   print(tab_res.macro)
   local tab = test(network, tdata, paramsModel)
   print("tab")
   print(tab.isAssociatedWith)
   --for i=2,#tdata.relationhash do
   for r, _ in pairs(paramsModel.onlylabel) do
      table.insert(tab_res[r].f1, tab[r].f1==tab[r].f1 and tab[r].f1 or 0)
      table.insert(tab_res[r].precision, tab[r].precision==tab[r].precision and tab[r].precision or 0)
      table.insert(tab_res[r].recall, tab[r].recall==tab[r].recall and tab[r].recall or 0)
   end
   table.insert(tab_res.macro.recall, tab.macro_avg.recall)
   table.insert(tab_res.macro.precision, tab.macro_avg.precision)
   table.insert(tab_res.macro.f1, tab.macro_avg.f1)
   table.insert(tab_res.micro.recall, tab.micro_avg.recall)
   table.insert(tab_res.micro.precision, tab.micro_avg.precision)
   table.insert(tab_res.micro.f1, tab.micro_avg.f1)
   
   _file = handle:read()
end


print(tab_res)

for r, _ in pairs(paramsModel.onlylabel) do
   
   local avg_p = torch.Tensor(tab_res[r].precision):mean()
   local avg_r = torch.Tensor(tab_res[r].recall):mean()
   local avg_f1 = torch.Tensor(tab_res[r].f1):mean()
   local std_f1 = f_std(tab_res[r].f1, avg_f1)
   --print("p\t" .. string.format("%.2f",avg_p*100) .. "\tr\t" .. string.format("%.2f",avg_r*100) .. "\tf1\t" .. string.format("%.2f",avg_f1*100) .. " ( " .. string.format("%.2f",std_f1*100) .. " )\t" .. r)
   print("" .. string.format("%.2f",avg_p*100) .. " / " .. string.format("%.2f",avg_r*100) .. " / " .. string.format("%.2f",avg_f1*100) .. " (" .. string.format("%.2f",std_f1*100) .. ")\t" .. r)
end

local avg_p = torch.Tensor(tab_res.macro.precision):mean()
local avg_r = torch.Tensor(tab_res.macro.recall):mean()
local avg_f1 = torch.Tensor(tab_res.macro.f1):mean()
local std_f1 = f_std(tab_res.macro.f1, avg_f1)
--print("p\t" .. string.format("%.2f",avg_p*100) .. "\tr\t" .. string.format("%.2f",avg_r*100) .. "\tf1\t" .. string.format("%.2f",avg_f1*100) .. " ( " .. string.format("%.2f",std_f1*100) .. " )\t" .. "macro")
print("" .. string.format("%.2f",avg_p*100) .. " / " .. string.format("%.2f",avg_r*100) .. " / " .. string.format("%.2f",avg_f1*100) .. " (" .. string.format("%.2f",std_f1*100) .. ")\t" .. "macro")

local avg_p = torch.Tensor(tab_res.micro.precision):mean()
local avg_r = torch.Tensor(tab_res.micro.recall):mean()
local avg_f1 = torch.Tensor(tab_res.micro.f1):mean()
local std_f1 = f_std(tab_res.micro.f1, avg_f1)
--print("p\t" .. string.format("%.2f",avg_p*100) .. "\tr\t" .. string.format("%.2f",avg_r*100) .. "\tf1\t" .. string.format("%.2f",avg_f1*100) .. " ( " .. string.format("%.2f",std_f1*100) .. " )\t" .. "micro")
print("" .. string.format("%.2f",avg_p*100) .. " / " .. string.format("%.2f",avg_r*100) .. " / " .. string.format("%.2f",avg_f1*100) .. " (" .. string.format("%.2f",std_f1*100) .. ")\t" .. "micro")
