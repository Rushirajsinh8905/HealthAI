import torch

device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print("Using device:", device)

x = torch.randn(3000, 3000, device=device)
y = torch.matmul(x, x)

print("Computation finished on", device)
