# Neovim Image and Math Preview Tests

In normal mode, move the cursor onto the image links or formulas below.
Math popups appear after the cursor stays still for about 250 ms.
The first preview may take longer while LaTeX converts the formula.

## 1. Local Image

Place the cursor on the image-link line below. The wallpaper from this repository
should appear in a popup. The path is relative to this Markdown file.

![Local wallpaper](../hypr-vm/windows-11-blue-ub.jpg)

Move to this line and check that the image popup closes.

## 2. Remote Image

Place the cursor on the link below. The image should be downloaded and displayed.
This test requires an internet connection.

![Remote Neovim icon](https://raw.githubusercontent.com/github/explore/main/topics/neovim/neovim.png)

Move to this line and check that the image popup closes.

## 3. Inline Math

Move the cursor between the dollar signs of each formula.

Basic formula: $\alpha + x^2 + y^2 = z^2$.

Fractions and square roots: $\frac{1}{\sqrt{2\pi}} e^{-x^2/2}$.

Subscripts and Greek letters: $\theta_i = \alpha_i + \beta_{i+1}$.

Repeated formula: $\alpha + x^2 + y^2 = z^2$.

The last formula matches the first one and should reuse the cached PNG.

## 4. Block Math

Summation:

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$

Integral:

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

Matrix:

$$
A = \begin{pmatrix}
1 & 2 \\
3 & 4
\end{pmatrix},
\qquad \det(A) = -2
$$

Aligned equations:

$$
\begin{aligned}
f(x) &= (x+1)^2 \\
     &= x^2 + 2x + 1
\end{aligned}
$$

## 5. Popup Behavior Checklist

- [ ] The local image appears when the cursor is on its link.
- [ ] The remote image downloads and appears when the cursor is on its link.
- [ ] Inline and block formulas appear as rendered math popups.
- [ ] Moving the cursor to ordinary text closes the popup.
- [ ] Entering insert mode closes an open math popup.
- [ ] Scrolling or switching windows leaves no stale math popup on screen.
- [ ] Moving quickly between formulas does not display an outdated result later.
- [ ] Revisiting the same formula reuses the cached image.

## 6. Markview Toggles

- `<Space>mp`: Toggle document rendering.
- `<Space>ms`: Toggle the split preview.

Markview document styling and image/math popups are separate features.

## Troubleshooting

Run `:PreviewDebugStart`, reproduce the issue, then run `:PreviewDebugStop`.
Print the log path with `:lua print(vim.fn.stdpath("cache") .. "/document-preview.log")`.
