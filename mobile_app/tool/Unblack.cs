using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Unblack {
    // Removes a solid black background. With level L = brightness above the noise floor (0..1), it uses
    // alpha = L^Gamma and colour = pixel / alpha, so colour * alpha reproduces the original on black.
    // Gamma < 1 keeps dark blues opaque (dark blue on white rather than a washed-out tint); pixels at or
    // below the noise floor (JPEG artefacts) become fully transparent.
    const double Gamma = 0.55;

    public static Bitmap Extract(Bitmap src, Rectangle crop, int noiseFloor) {
        Bitmap input = src.Clone(crop, PixelFormat.Format32bppArgb);
        Bitmap output = new Bitmap(crop.Width, crop.Height, PixelFormat.Format32bppArgb);
        Rectangle r = new Rectangle(0, 0, crop.Width, crop.Height);
        BitmapData inData = input.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData outData = output.LockBits(r, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int bytes = inData.Stride * crop.Height;
        byte[] px = new byte[bytes];
        Marshal.Copy(inData.Scan0, px, 0, bytes);
        for (int i = 0; i < bytes; i += 4) {
            int b = px[i], g = px[i + 1], rd = px[i + 2];
            int max = Math.Max(rd, Math.Max(g, b));
            if (max <= noiseFloor) {
                px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0;
                continue;
            }
            double level = (max - noiseFloor) / (255.0 - noiseFloor);
            double alpha = Math.Pow(level, Gamma);
            double factor = 255.0 * Math.Pow(level, 1 - Gamma) / max;
            px[i] = (byte)Math.Min(255, (int)Math.Round(b * factor));
            px[i + 1] = (byte)Math.Min(255, (int)Math.Round(g * factor));
            px[i + 2] = (byte)Math.Min(255, (int)Math.Round(rd * factor));
            px[i + 3] = (byte)Math.Round(alpha * 255);
        }
        Marshal.Copy(px, 0, outData.Scan0, bytes);
        input.UnlockBits(inData);
        output.UnlockBits(outData);
        input.Dispose();
        return Trim(output);
    }

    static Bitmap Trim(Bitmap bmp) {
        int minX = bmp.Width, minY = bmp.Height, maxX = 0, maxY = 0;
        Rectangle r = new Rectangle(0, 0, bmp.Width, bmp.Height);
        BitmapData d = bmp.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] px = new byte[d.Stride * bmp.Height];
        Marshal.Copy(d.Scan0, px, 0, px.Length);
        int stride = d.Stride;
        bmp.UnlockBits(d);
        for (int y = 0; y < bmp.Height; y++) {
            for (int x = 0; x < bmp.Width; x++) {
                if (px[y * stride + x * 4 + 3] > 8) {
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }
        }
        int pad = 8;
        Rectangle box = Rectangle.FromLTRB(Math.Max(0, minX - pad), Math.Max(0, minY - pad),
                Math.Min(bmp.Width, maxX + pad + 1), Math.Min(bmp.Height, maxY + pad + 1));
        Bitmap trimmed = bmp.Clone(box, PixelFormat.Format32bppArgb);
        bmp.Dispose();
        return trimmed;
    }

    // Centres the artwork on a transparent square canvas at the given fraction of its size.
    public static Bitmap Square(Bitmap art, int size, double scale) {
        Bitmap canvas = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(canvas)) {
            g.Clear(Color.Transparent);
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            double f = Math.Min(size * scale / art.Height, size * scale / art.Width);
            int w = (int)(art.Width * f), h = (int)(art.Height * f);
            g.DrawImage(art, (size - w) / 2, (size - h) / 2, w, h);
        }
        return canvas;
    }

    public static void Run(string dir) {
        using (Bitmap src = new Bitmap(dir + "\\logo_full.jpg")) {
            using (Bitmap full = Extract(src, new Rectangle(0, 0, src.Width, src.Height), 14)) {
                full.Save(dir + "\\logo_transparent.png", ImageFormat.Png);
                Console.WriteLine("full: " + full.Width + "x" + full.Height);
            }
            using (Bitmap mark = Extract(src, new Rectangle(280, 15, 960, 945), 14)) {
                mark.Save(dir + "\\logo_mark_transparent.png", ImageFormat.Png);
                Console.WriteLine("mark: " + mark.Width + "x" + mark.Height);
                // Android adaptive icon foreground: transparent, mark inside the ~66% safe zone.
                using (Bitmap fg = Square(mark, 1024, 0.58)) {
                    fg.Save(dir + "\\app_icon_foreground.png", ImageFormat.Png);
                }
            }
        }
    }
}
