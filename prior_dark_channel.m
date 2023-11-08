clear,clc;
% 读取图片
 image1 = imread('R-C.jpg');

% 获取图片的尺寸
[rows, ~, ~] = size(image1);

% 指定左下角区域的宽度和高度
width = 1000;
height = 1000;

% 切割左下角的区域
image = image1(rows-height+1:rows, 1:width, :);

% 显示或保存切割后的图片
%imshow(croppedImage);
imwrite(image, 'RC_image.jpg');
%%
clear,clc;
% 读取图像
 image = imread('RC_image.jpg');
figure;
% subplot(2, 2, 1);
imshow(image);
%%
% 计算彩色图像中每个点的最小值
grayimage = min(image, [], 3); % 在第三维度上找最小值，即R、G、B通道

% 显示灰度图像
% figure;
% subplot(2, 2, 2);
% imshow(grayimage);
% 如果需要，你也可以保存灰度图像为文件
% imwrite(grayImage, 'gray_image.jpg');
%%
%···················································局部区域最小化：暗通道图······················································%
% 获取图像的尺寸
[rows, cols] = size(grayimage);

% 定义局部窗口大小
windowSize = 3;

% 创建一个空白的图像，与原图像大小相同
I_dark = grayimage;

% 遍历图像中的每个像素
for i = 1:rows
    for j = 1:cols
        % 获取当前像素的局部窗口范围
        rowStart = max(i - floor(windowSize / 2), 1);%floor:将 X 的每个元素四舍五入到小于或等于该元素的最接近整数
        rowEnd = min(i + floor(windowSize / 2), rows);
        colStart = max(j - floor(windowSize / 2), 1);
        colEnd = min(j + floor(windowSize / 2), cols);
        
        % 获取局部窗口
        localWindow = grayimage(rowStart:rowEnd, colStart:colEnd, :);
        
        % 计算局部窗口中的最小值
        minVal = min(localWindow(:));
        
        % 用局部窗口的最小值覆盖当前像素的值
        I_dark(i, j, :) = minVal;
    end
end

% 显示覆盖后的图像
figure;
imshow(I_dark);
title('暗通道图')       
%%
%······················································全局大气光估计······························································%
% 获取图像的尺寸
[rows, cols, ~] = size(image);

% 计算暗通道图中前0.1%的最亮像素数量
numPixels = numel(I_dark);
numBrightestPixels = round(0.001 * numPixels);

% 找到暗通道图中前0.1%的最亮像素值和坐标
[sortedValues, sortedIndices] = sort(I_dark(:), 'descend');
brightestPixelIndices = sortedIndices(1:numBrightestPixels);

% 初始化数组来存储对应的最亮点在彩色图中的像素值
brightestPixelsInColor = zeros(numBrightestPixels, 3);

% 找到彩色图中对应的最亮点
for i = 1:numBrightestPixels
    [row, col] = ind2sub([rows, cols], brightestPixelIndices(i));
    for channel = 1:3
        brightestPixelsInColor(i, channel) = image(row, col, channel);
    end
end

% 在最亮点中找到最亮的像素值作为全局大气光A的估计
A_r = max(brightestPixelsInColor(:, 1));
A_g = max(brightestPixelsInColor(:, 2));
A_b = max(brightestPixelsInColor(:, 3));

%第二种方法:用前0.1%的平均值作为A的值
% A_r = mean(brightestPixelsInColor(:, 1));
% A_g = mean(brightestPixelsInColor(:, 2));
% A_b = mean(brightestPixelsInColor(:, 3));

%%
%·······················································透射率粗略估计····························································%
% 归一化彩色图像
I_normalized = double(image) ./ cat(3, A_r, A_g, A_b);

% 创建一个空白的图像，与原图像大小相同
t_x = I_normalized;

% 遍历图像中的每个像素
for i = 1:rows
    for j = 1:cols
        % 获取当前像素的局部窗口范围
        rowStart = max(i - floor(windowSize / 2), 1);
        rowEnd = min(i + floor(windowSize / 2), rows);
        colStart = max(j - floor(windowSize / 2), 1);
        colEnd = min(j + floor(windowSize / 2), cols);
        
        % 获取局部窗口
        localWindow = I_normalized(rowStart:rowEnd, colStart:colEnd, :);
        
        % 计算局部窗口中的最小值
        minVal = min(localWindow(:));
        
        % 用局部窗口的最小值覆盖当前像素的值
        t_x(i, j, :) = minVal;
    end
end

w=0.98;%修正参数,去掉雾的程度是98%
t_x1=1-w*t_x;
figure;
imshow(t_x1);%粗略透射率图
title('粗略透射率图')
%%
%······················································透射率精细化····························································%


%%
%······················································估计深度····························································%
% beta=0.1;%大气散射系数
% d_k=-1/beta*log(t_x1);
% figure;
% imshow(d_k);%粗略深度图

%%
%······················································全图去雾····························································%
% 分别对每个通道进行去雾处理
newImage = zeros(rows, cols, 3);
t_0=0.1;%引入常量，防止传输率过曝
t_x1(t_x1 < t_0) = t_0;
for channel = 1:3
    % 分别减去各自通道的全局大气光值，然后除以各自通道的传输率，最后加上各自通道的全局大气光值
    if channel == 1
     
        newImage(:, :, channel) = (double(image(:, :, channel)) - A_r) ./ t_x1(:,:,channel) + A_r; 
  
    elseif channel == 2

        newImage(:, :, channel) = (double(image(:, :, channel)) - A_g) ./ t_x1(:,:,channel) + A_g;
    else
        newImage(:, :, channel) = (double(image(:, :, channel)) - A_b) ./ t_x1(:,:,channel) + A_b;
    end
end

% 将像素值限制在[0, 255]范围内
newImage(newImage < 0) = 0;
newImage(newImage > 255) = 255;

% 转换数据类型为uint8
newImage = uint8(newImage);

figure;
imshow(newImage);% 显示去雾图

