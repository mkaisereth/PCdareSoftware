import torch
import torch.nn as nn
from torch.nn import functional as F

class DiceCoefficient(nn.Module):

    def __init__(self):
        super(DiceCoefficient, self).__init__()
        
    def forward(self, y_pred, y_true):

        assert y_pred.shape[0] == y_true.shape[0], "predict & target batch size don't match"
        y_pred = y_pred.contiguous().view(y_pred.shape[0], -1)
        y_true = y_true.contiguous().view(y_true.shape[0], -1)

        y_true_binary = torch.where(y_true >= 0.5, 1., 0.)
        y_pred_binary = torch.where(y_pred >= 0.5, 1., 0.)

        num = 2.*torch.sum(torch.mul(y_pred_binary, y_true_binary), dim=1)
        den = torch.sum(y_pred_binary.pow(1) + y_true_binary.pow(1), dim=1)

        loss = num / den

        return loss.mean()