import torch
import torch.nn as nn
import brevitas.nn as qnn
from brevitas.quant import Int8WeightPerTensorFloat as Int8Weight
from brevitas.quant import SignedBinaryWeightPerTensorConst as BinWeight
from brevitas.quant import SignedBinaryActPerTensorConst as BinAct

class PCBFaultBNN(nn.Module):
    def __init__(self):
        super(PCBFaultBNN, self).__init__()
        
        
        self.layer1 = qnn.QuantLinear(1024, 512, bias=False, weight_quant=Int8Weight)
        self.bn1 = nn.BatchNorm1d(512)
        self.bin_act1 = qnn.QuantIdentity(act_quant=BinAct)
        
        
        self.layer2 = qnn.QuantLinear(512, 256, bias=False, weight_quant=BinWeight)
        self.bn2 = nn.BatchNorm1d(256)
        self.bin_act2 = qnn.QuantIdentity(act_quant=BinAct)
        
        
        self.layer3 = qnn.QuantLinear(256, 128, bias=False, weight_quant=BinWeight)
        self.bn3 = nn.BatchNorm1d(128)
        self.bin_act3 = qnn.QuantIdentity(act_quant=BinAct)

        
        self.fc_out = qnn.QuantLinear(128, 8, bias=False, weight_quant=BinWeight)
        

    def forward(self, x):
        
        x = x.view(-1, 1024) 
        
        x = self.bin_act1(self.bn1(self.layer1(x)))
        x = self.bin_act2(self.bn2(self.layer2(x)))
        x = self.bin_act3(self.bn3(self.layer3(x)))
        x = self.fc_out(x)
        return x