import torch
import torch.nn as nn
from torch.nn import functional as F

class Loss(nn.Module):

    def __init__(self):
        super(Loss, self).__init__()
        self.smooth = 1.0
        
    def forward(self, y_pred, y_true):

        assert y_pred.shape[0] == y_true.shape[0], "predict & target batch size don't match"
        y_pred = y_pred.contiguous().view(y_pred.shape[0], -1)
        y_true = y_true.contiguous().view(y_true.shape[0], -1)

        num = 2.*torch.sum(torch.mul(y_pred, y_true), dim=1) + self.smooth
        den = torch.sum(y_pred.pow(1) + y_true.pow(1), dim=1) + self.smooth

        BCE = F.binary_cross_entropy(y_pred, y_true, reduction='mean')
        
        loss = 1 - num / den

        dice_loss = loss.mean()

        return dice_loss, BCE, dice_loss + BCE


class BCE(nn.Module):

    def __init__(self):
        super().__init__()

    def forward(self, y_pred, y_true):
        
        assert y_pred.shape[0] == y_true.shape[0], "predict & target batch size don't match"
        y_pred = y_pred.contiguous().view(y_pred.shape[0], -1)
        y_true = y_true.contiguous().view(y_true.shape[0], -1)


        BCE = F.binary_cross_entropy(y_pred, y_true, reduction='mean')

        return BCE 

        