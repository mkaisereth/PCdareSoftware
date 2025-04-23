from torch.utils.data import Dataset
import pathlib
from torchvision.io import read_image
import posixpath


class XRayDataset(Dataset):
    def __init__(self, data_path: pathlib.Path, transform_inputs, transform_labels):
       
        self.images = []
        self.labels = []

        png_filenames = [str(file_path) for file_path in sorted(data_path.glob("*.jpg"), key = lambda i: (len(posixpath.basename(i)), i)) if file_path.is_file()]
        self.files = [f for f in png_filenames if 'label' not in f]

        self.transform_inputs = transform_inputs
        self.transform_labels = transform_labels

    def __len__(self):
        return len(self.files)

    def __getitem__(self, idx):
        f = self.files[idx]
        image = self.transform_inputs(read_image(f))
        label = self.transform_labels(read_image(f.replace(".jpg", "_label.jpg")))
        return image, label
        
    def get_filename(self, idx):
        return self.files[idx]


class XRayDataset2(Dataset):
    def __init__(self, data_path: pathlib.Path, transform_inputs):
       
        self.images = []

        png_filenames = [str(file_path) for file_path in sorted(data_path.glob("*.jpg"), key = lambda i: (len(posixpath.basename(i)), i)) if file_path.is_file()]
        self.files = [f for f in png_filenames if 'label' not in f]

        self.transform_inputs = transform_inputs

    def __len__(self):
        return len(self.files)

    def __getitem__(self, idx):
        f = self.files[idx]
        image = self.transform_inputs(read_image(f))
        return image
        
    def get_filename(self, idx):
        return self.files[idx]
