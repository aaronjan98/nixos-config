import cv2
import numpy as np
import sys
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt

if len(sys.argv) != 3:
    sys.exit("usage: scan.py <input.jpg> <output.jpg>")

img = cv2.imread(sys.argv[1])
if img is None:
    sys.exit(f"could not read {sys.argv[1]}")

rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

plt.figure(figsize=(14, 9))
plt.imshow(rgb)
plt.title("click 4 corners in order: TL, TR, BR, BL — then close window")
plt.tight_layout()
points = plt.ginput(4, timeout=0)
plt.close()

if len(points) != 4:
    sys.exit(f"need 4 corners, got {len(points)}")

pts = np.array(points, dtype="float32")
(tl, tr, br, bl) = pts
w = int(max(np.linalg.norm(br - bl), np.linalg.norm(tr - tl)))
h = int(max(np.linalg.norm(tr - br), np.linalg.norm(tl - bl)))
dst = np.array([[0, 0], [w - 1, 0], [w - 1, h - 1], [0, h - 1]], dtype="float32")

M = cv2.getPerspectiveTransform(pts, dst)
warped = cv2.warpPerspective(img, M, (w, h))

lab = cv2.cvtColor(warped, cv2.COLOR_BGR2LAB)
l, a, b = cv2.split(lab)
clahe = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8))
l = clahe.apply(l)
warped = cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)

cv2.imwrite(sys.argv[2], warped, [cv2.IMWRITE_JPEG_QUALITY, 95])
print(f"wrote {sys.argv[2]}")
