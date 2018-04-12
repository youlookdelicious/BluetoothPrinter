//
//  HLPrinter.m
//  HLBluetoothDemo
//
//  Created by Harvey on 16/5/3.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import "HLPrinter.h"
#import "UIImage+Compress.h"
#import "ImageProcessor.h"
#import "SEPrinterManager.h"
#define kMargin 20
#define kPadding 2
#define kWidth 320

@interface HLPrinter ()

/** 将要打印的排版后的数据 */
@property (strong, nonatomic)   NSMutableData            *printerData;

@end

@implementation HLPrinter

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self defaultSetting];
    }
    return self;
}

- (void)defaultSetting
{
    _printerData = [[NSMutableData alloc] init];
    
    // 1.初始化打印机
    Byte initBytes[] = {0x1B,0x40};
    [_printerData appendBytes:initBytes length:sizeof(initBytes)];
    // 2.设置行间距为1/6英寸，约34个点
    // 另一种设置行间距的方法看这个 @link{-setLineSpace:}
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
    // 3.设置字体:标准0x00，压缩0x01;
    Byte fontBytes[] = {0x1B,0x4D,0x00};
    [_printerData appendBytes:fontBytes length:sizeof(fontBytes)];

}

#pragma mark - -------------基本操作----------------
/**
 *  换行
 */
- (void)appendNewLine
{
    Byte nextRowBytes[] = {0x0A};
    [_printerData appendBytes:nextRowBytes length:sizeof(nextRowBytes)];
}

/**
 *  回车
 */
- (void)appendReturn
{
    Byte returnBytes[] = {0x0D};
    [_printerData appendBytes:returnBytes length:sizeof(returnBytes)];
}

/**
 *  设置对齐方式
 *
 *  @param alignment 对齐方式：居左、居中、居右
 */
- (void)setAlignment:(HLTextAlignment)alignment
{
    Byte alignBytes[] = {0x1B,0x61,alignment};
    [_printerData appendBytes:alignBytes length:sizeof(alignBytes)];
}

/**
 *  设置字体大小
 *
 *  @param fontSize 字号
 */
- (void)setFontSize:(HLFontSize)fontSize
{
    Byte fontSizeBytes[] = {0x1D,0x21,fontSize};
    [_printerData appendBytes:fontSizeBytes length:sizeof(fontSizeBytes)];
}

/**
 *  添加文字，不换行
 *
 *  @param text 文字内容
 */
- (void)setText:(NSString *)text
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [text dataUsingEncoding:enc];
    [_printerData appendData:data];
}

/**
 *  添加文字，不换行
 *
 *  @param text    文字内容
 *  @param maxChar 最多可以允许多少个字节,后面加...
 */
- (void)setText:(NSString *)text maxChar:(int)maxChar
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [text dataUsingEncoding:enc];
    if (data.length > maxChar) {
        data = [data subdataWithRange:NSMakeRange(0, maxChar)];
        text = [[NSString alloc] initWithData:data encoding:enc];
        if (!text) {
            data = [data subdataWithRange:NSMakeRange(0, maxChar - 1)];
            text = [[NSString alloc] initWithData:data encoding:enc];
        }
        text = [text stringByAppendingString:@"..."];
    }
    [self setText:text];
}

/**
 *  设置偏移文字
 *
 *  @param text 文字
 */
- (void)setOffsetText:(NSString *)text
{
    // 1.计算偏移量,因字体和字号不同，所以计算出来的宽度与实际宽度有误差(小字体与22字体计算值接近)
    NSDictionary *dict = @{NSFontAttributeName:[UIFont systemFontOfSize:22.0]};
    NSAttributedString *valueAttr = [[NSAttributedString alloc] initWithString:text attributes:dict];
    int valueWidth = valueAttr.size.width;
    
    // 2.设置偏移量
    [self setOffset:368 - valueWidth];
    
    // 3.设置文字
    [self setText:text];
}

/**
 *  设置偏移量
 *
 *  @param offset 偏移量
 */
- (void)setOffset:(NSInteger)offset
{
    NSInteger remainder = offset % 256;
    NSInteger consult = offset / 256;
    Byte spaceBytes2[] = {0x1B, 0x24, remainder, consult};
    [_printerData appendBytes:spaceBytes2 length:sizeof(spaceBytes2)];
}

/**
 *  设置行间距
 *
 *  @param points 多少个点
 */
- (void)setLineSpace:(NSInteger)points
{
    //最后一位，可选 0~255
    Byte lineSpace[] = {0x1B,0x33,60};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

/**
 *  设置二维码模块大小
 *
 *  @param size  1<= size <= 16,二维码的宽高相等
 */
- (void)setQRCodeSize:(NSInteger)size
{
    Byte QRSize [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x43,size};
    //    Byte QRSize [] = {29,40,107,3,0,49,67,size};
    [_printerData appendBytes:QRSize length:sizeof(QRSize)];
}

/**
 *  设置二维码的纠错等级
 *
 *  @param level 48 <= level <= 51
 */
- (void)setQRCodeErrorCorrection:(NSInteger)level
{
    Byte levelBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x45,level};
    //    Byte levelBytes [] = {29,40,107,3,0,49,69,level};
    [_printerData appendBytes:levelBytes length:sizeof(levelBytes)];
}

/**
 *  将二维码数据存储到符号存储区
 * [范围]:  4≤(pL+pH×256)≤7092 (0≤pL≤255,0≤pH≤27)
 * cn=49
 * fn=80
 * m=48
 * k=(pL+pH×256)-3, k就是数据的长度
 *
 *  @param info 二维码数据
 */
- (void)setQRCodeInfo:(NSString *)info
{
    NSInteger kLength = info.length + 3;
    NSInteger pL = kLength % 256;
    NSInteger pH = kLength / 256;
    
    Byte dataBytes [] = {0x1D,0x28,0x6B,pL,pH,0x31,0x50,48};
    //    Byte dataBytes [] = {29,40,107,pL,pH,49,80,48};
    [_printerData appendBytes:dataBytes length:sizeof(dataBytes)];
    NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
    [_printerData appendData:infoData];
    //    [self setText:info];
}

/**
 *  打印之前存储的二维码信息
 */
- (void)printStoredQRData
{
    Byte printBytes [] = {0x1D,0x28,0x6B,0x03,0x00,0x31,0x51,48};
    //    Byte printBytes [] = {29,40,107,3,0,49,81,48};
    [_printerData appendBytes:printBytes length:sizeof(printBytes)];
}

#pragma mark - ------------function method ----------------
#pragma mark  文字
- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment
{
    [self appendText:text alignment:alignment fontSize:HLFontSizeTitleSmalle];
}

- (void)appendText:(NSString *)text alignment:(HLTextAlignment)alignment fontSize:(HLFontSize)fontSize
{
    // 1.文字对齐方式
    [self setAlignment:alignment];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:text];
    // 4.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (void)appendTitle:(NSString *)title value:(NSString *)value
{
    [self appendTitle:title value:value fontSize:HLFontSizeTitleSmalle];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value fontSize:(HLFontSize)fontSize
{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:title];
    // 4.设置实际值
    [self setOffsetText:value];
    // 5.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset
{
    [self appendTitle:title value:value valueOffset:offset fontSize:HLFontSizeTitleSmalle];
}

- (void)appendTitle:(NSString *)title value:(NSString *)value valueOffset:(NSInteger)offset fontSize:(HLFontSize)fontSize
{
    // 1.设置对齐方式
    [self setAlignment:HLTextAlignmentLeft];
    // 2.设置字号
    [self setFontSize:fontSize];
    // 3.设置标题内容
    [self setText:title];
    // 4.设置内容偏移量
    [self setOffset:offset];
    // 5.设置实际值
    [self setText:value];
    // 6.换行
    [self appendNewLine];
    if (fontSize != HLFontSizeTitleSmalle) {
        [self appendNewLine];
    }
}

- (void)appendLeftText:(NSString *)left middleText:(NSString *)middle rightText:(NSString *)right isTitle:(BOOL)isTitle
{
    [self setAlignment:HLTextAlignmentLeft];
    [self setFontSize:HLFontSizeTitleSmalle];
    NSInteger offset = 0;
    if (!isTitle) {
        offset = 10;
    }
    
    if (left) {
        [self setText:left maxChar:10];
    }
    
    if (middle) {
        [self setOffset:150 + offset];
        [self setText:middle];
    }
    
    if (right) {
        [self setOffset:300 + offset];
        [self setText:right];
    }
    
    [self appendNewLine];
    
}

#pragma mark 图片
- (void)appendImage:(UIImage *)image alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    if (!image) {
        return;
    }
    
    // 1.设置图片对齐方式
    [self setAlignment:alignment];
    
    // 2.设置图片
    // 这里需要特别注意！！！！！
    /*
     目前打印机很多种，从两方面分，一种支持png打印，一种只支持jpg打印。
     比如我项目用的“恩叶NP100”,只支持jpg，用这个demo原作者的代码打印二维码时一直乱码。
     现在我的代码在这里进行区分，一种是原作者的代码，另一个是我加的用来打印例如“恩叶打印机”这种的。
     */
    
    //这个是我写的用来支持“恩叶”打印二维码的代码
    UIImage *outputImage = [self POS_PrintBMP:image width:IMGWIDTH mode:0];
    [self processImageData:outputImage];
    //这个是原作者写的，原作者说支持以下打印机：佳博 Gp-58MBIII和GP58MBIII和芯烨XPrinter某型号。
//    UIImage *newImage = [image imageWithscaleMaxWidth:maxWidth];
//
//    NSData *imageData = [newImage bitmapData];
//    [_printerData appendData:imageData];
    
    
    // 3.换行
    [self appendNewLine];
    
    // 4.打印图片后，恢复文字的行间距
    Byte lineSpace[] = {0x1B,0x32};
    [_printerData appendBytes:lineSpace length:sizeof(lineSpace)];
}

- (void)appendBarCodeWithInfo:(NSString *)info
{
    [self appendBarCodeWithInfo:info alignment:HLTextAlignmentCenter maxWidth:IMGWIDTH];
}

- (void)appendBarCodeWithInfo:(NSString *)info alignment:(HLTextAlignment)alignment maxWidth:(CGFloat)maxWidth
{
    UIImage *barImage = [UIImage barCodeImageWithInfo:info];
    [self appendImage:barImage alignment:alignment maxWidth:maxWidth];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size
{
    [self appendQRCodeWithInfo:info size:size alignment:HLTextAlignmentCenter];
}

- (void)appendQRCodeWithInfo:(NSString *)info size:(NSInteger)size alignment:(HLTextAlignment)alignment
{
    [self setAlignment:alignment];
    [self setQRCodeSize:size];
    [self setQRCodeErrorCorrection:48];
    [self setQRCodeInfo:info];
    [self printStoredQRData];
    [self appendNewLine];
}

- (void)appendQRCodeWithInfo:(NSString *)info
{
    [self appendQRCodeWithInfo:info centerImage:nil alignment:HLTextAlignmentCenter maxWidth:250];
}

- (void)appendQRCodeWithInfo:(NSString *)info centerImage:(UIImage *)centerImage alignment:(HLTextAlignment)alignment maxWidth:(CGFloat )maxWidth
{
    UIImage *QRImage = [UIImage qrCodeImageWithInfo:info centerImage:centerImage width:maxWidth];
    [self appendImage:QRImage alignment:alignment maxWidth:maxWidth];
}

#pragma mark 其他
- (void)appendSeperatorLine
{
    // 1.设置分割线居中
    [self setAlignment:HLTextAlignmentCenter];
    // 2.设置字号
    [self setFontSize:HLFontSizeTitleSmalle];
    // 3.添加分割线
    NSString *line = @"- - - - - - - - - - - - - - - -";
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSData *data = [line dataUsingEncoding:enc];
    [_printerData appendData:data];
    // 4.换行
    [self appendNewLine];
}

- (void)appendFooter:(NSString *)footerInfo
{
    [self appendSeperatorLine];
    if (!footerInfo) {
        footerInfo = @"谢谢惠顾，欢迎下次光临！";
    }
    [self appendText:footerInfo alignment:HLTextAlignmentCenter];
}

- (NSData *)getFinalData
{
    return _printerData;
}



//  HYH修改部分
- (UIImage *)POS_PrintBMP:(UIImage *)src width:(NSUInteger)nWidth mode:(NSUInteger)nMode {
    NSUInteger width = ((nWidth + 7) / 8) * 8;
    [src jpeg:Lowest];
    UIImage *resizeImage = src;
    if (src.size.width != width) {
        resizeImage = [self scaleWithFixedWidth:width image:src];
    }
    //    [self processImageData:resizeImage];
    UIImage * img = [[ImageProcessor shared] processImage:resizeImage];
    return img;
}

- (UIImage *)scaleWithFixedWidth:(CGFloat)width image:(UIImage *)image {
    CGImageRef inputImageRef = [image CGImage];
    float newHeight = CGImageGetHeight(inputImageRef) * (width / CGImageGetWidth(inputImageRef));
    CGSize size = CGSizeMake(width, newHeight);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), image.CGImage);
    
    UIImage *imageOut = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imageOut;
}

- (void)processImageData:(UIImage *)inputImage {
    NSLog(@"%s", __FUNCTION__);
    const int RED = 1;
    const int GREEN = 2;
    const int BLUE = 3;
    
    int width = inputImage.size.width;
    int height = inputImage.size.height;
    int imgSize = width * height;
    int x_origin = 0;
    int y_to = height;
    
    /**
     GET PIXEL FROM IMAGE
     */
    // the pixels will be painted to this array
    uint32_t *pixels = (uint32_t *) malloc(imgSize * sizeof(uint32_t));
    
    // clear the pixels so any transparency is preserved
    memset(pixels, 0, imgSize * sizeof(uint32_t));
    
    NSInteger nWidthByteSize = (width+7)/8;
    
    NSInteger nBinaryImgDataSize = nWidthByteSize * y_to;
    Byte *binaryImgData = (Byte *)malloc(sizeof(Byte) * nBinaryImgDataSize);
    
    memset(binaryImgData, 0, nBinaryImgDataSize);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // create a context with RGBA pixels
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                 width,
                                                 height,
                                                 8,
                                                 width * sizeof(uint32_t),
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
    
    // paint the bitmap to our context which will fill in the pixels array
    CGContextDrawImage(context, CGRectMake(0, 0, width , height), [inputImage CGImage]);
    
    for(int y = 0; y < y_to; y++) {
        for(int x = x_origin; x < width ; x++) {
            uint8_t *rgbaPixel = (uint8_t *) &pixels[y * width + x];
            
            // convert to grayscale using recommended method: http://en.wikipedia.org/wiki/Grayscale#Converting_color_to_grayscale
            uint32_t gray = 0.3 * rgbaPixel[RED] + 0.59 * rgbaPixel[GREEN] + 0.11 * rgbaPixel[BLUE];
            if (gray < 127) {
                rgbaPixel[RED] = 0;
                rgbaPixel[GREEN] = 0;
                rgbaPixel[BLUE] = 0;
                binaryImgData[(y*width+x)/8] |= (0x80>>(x%8));
            } else {
                rgbaPixel[RED] = 255;
                rgbaPixel[GREEN] = 255;
                rgbaPixel[BLUE] = 255;
            }
        }
    }
    
    
    NSUInteger offset = 0;
    for (int y = 0; y < height; y++) {
        Byte *SET_BIT_IMAGE_MODE = (Byte *)malloc(8 + nWidthByteSize);
        memset(SET_BIT_IMAGE_MODE, 0, 8 + nWidthByteSize);
        SET_BIT_IMAGE_MODE[0] = 0x1d;
        SET_BIT_IMAGE_MODE[1] = 0x76;//'v';
        SET_BIT_IMAGE_MODE[2] = 0x30;
        SET_BIT_IMAGE_MODE[3] = (Byte)0;
        SET_BIT_IMAGE_MODE[4] = (Byte)(nWidthByteSize & 0xff);
        SET_BIT_IMAGE_MODE[5] = (Byte)((nWidthByteSize>>8) & 0xff);
        SET_BIT_IMAGE_MODE[6] = (Byte)(1 & 0xff);
        SET_BIT_IMAGE_MODE[7] = (Byte)((1>>8) & 0xff);
        
        for (int i = 0; i < nWidthByteSize; i++) {
            SET_BIT_IMAGE_MODE[8 + i] = *(binaryImgData + i + offset);
        }
        /**
         PRINT IMAGE
         */
        NSData *data = [[NSData alloc] initWithBytes:SET_BIT_IMAGE_MODE length:8 + nWidthByteSize];
        //        [sendDataArray addObject:data];
        [_printerData appendData:data];
        
        
        free(SET_BIT_IMAGE_MODE);
        SET_BIT_IMAGE_MODE = NULL;
        offset += nWidthByteSize;
    }
    
    free(pixels);
    free(binaryImgData);
    pixels = NULL;
    binaryImgData = NULL;
    
}
@end
