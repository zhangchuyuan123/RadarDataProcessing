% exercise1_part2
% Jileil @Hasco 2018-03-26
clc;clear;close all;
load trueTarget.mat;
rng(7);
%% UKF
% generate noisy measurement in non-linear coordinate
sigma_r = 100;
sigma_theta = 5;
% [   V_r(k)    ~ N([0 ,[sigma_r^2     0      
%  V_theta(k)]       0]      0    sigma_theta^2]
r = sqrt(trueTarget(2,:).^2 + trueTarget(3,:).^2);
theta = atan(trueTarget(3,:)./trueTarget(2,:))/pi*180;
%z_rho_theta =
Z_degree = [r;theta];

for i = 1:length(r)
    Z_degree(:,i) = Z_degree(:,i) + [100 0;0 5]*randn(2,1);
end

%%
%****************Remember Only measurement equation is different***********

% x0_: mean of x0, initialization of status vector
x0_ = [1000 1000 0 0]';
% P0 : the initialization of covariance matrix
P0 = [10000 0 0 0;
      0 10000 0 0;
      0  0  100 0;
      0  0  0 100];

% Assume time interval T = 1
T = 1;
% status transfer matrix in CV(constant-velocity) model as A or F:
% [I2 T*I2  =  [1 0 T 0
%  02 I2 ]     0 1 0 T
%              0 0 1 0
%              0 0 0 1]
A = [1 0 T 0;
     0 1 0 T;
     0 0 1 0;
     0 0 0 1];
% noisy transfer matrix in CV(constant-velocity) model as B or T:
% [0.5*T^2*I2 = [0.5T^2  0
%    T*I2]       0    0.5T^2
%                 T      0
%                 0      T]
B = [0.5*T^2    0;
       0     0.5*T^2;
       T        0;
       0        T;];
pnsigma = 1;
processNoiseSigma = [pnsigma^2 0;0 pnsigma^2];
% this is Q
% noiseVector = chol(eye(2))*randn(2,1);
% 过程噪声是预测过程中混入的噪声
Q = B * processNoiseSigma * B';%[4*4] 过程噪声在高斯模型下是一个常量
%*******************实践最原始的UKF*****************
n = 4;
L = 2 * n + 1;
xPredict_linear_hat = zeros(4,151);
xPredict_sumSigma_hat = zeros(4,151);
xEstimate = zeros(4,151);
% Initialize x0, p0
xEstimate(1:2,1) = [1000,1000];
pEstimate = zeros(16,151);

R = [100^2 0;0 5^2];

pPredict_sigmaPoint = zeros(L*16,151); % 对每一个sigma Point 都有一个协方差矩阵的预测
zPredict_sigmaPoint = zeros(2,L); % K时刻对每一个sigma Point 都有一个量测的预测
xPredict_sigmaPoint = zeros(4,L);  % 4, L
delta_x = zeros(1,n);
w0 = 1/9;
wi = (1 - w0)/(2*n); % 表示所有的点都是等权重么？
%%
for k = 2:151
    % 基于过程方程仍是linear, 处理方式与LKF相同
    pEstimate_reshape = reshape(pEstimate(:,k - 1),4,4);
    xPredict_linear_hat(:,k) = A * xEstimate(:,k - 1); % 1-step-ahead vector of state forecasts
    pPredict_linear = A * reshape(pEstimate(: , k - 1),4 , 4) * A.' + Q; %[4 4] % 1-step-ahead covariance
    % generate sigma point
    [u,s] = svd(pPredict_linear);
    xPredict_sigmaPoint(:,L) = xPredict_linear_hat(:,k); % x0 放在了sigmaPoint数列的最后
    delta_x = sqrt(n/(1-w0)) * u * sqrt(s); % get the square root of pEstimate and remain the same dimension
    
    %
    for i = 1:n
         % use basic 
        xPredict_sigmaPoint(:,i) = xPredict_linear_hat(:,k) + delta_x(:,i);
        xPredict_sigmaPoint(:,i + n) = xPredict_linear_hat(:,k) - delta_x(:,i);
    end
    
    
    %xPredict_sigmaPoint(4*j-3:4*j ,k) = A * sigmaPoint(:,j); % 每一个sigma点的预测
    %pPredict_sigmaPoint(16*j-15:16*j,k) = A * reshape(pEstimate(:,k - 1),4,4) * A.' + Q; % 每一个sigma点的预测协方差
    %由于状态方程是线性的，所以预测值和预测协方差都应该是唯一的，不需要求和
    %量测的预测
    zPredict_sigmaPoint(1,:) = sqrt(xPredict_sigmaPoint(1,:).^2 + xPredict_sigmaPoint(2,:).^2);
    zPredict_sigmaPoint(2,:) = atan(xPredict_sigmaPoint(2,:)./xPredict_sigmaPoint(1,:))/pi*180;% radius to degree
    %量测的协方差
    %因为 wi = w0
    zPredict = wi * sum(zPredict_sigmaPoint,2);
    zll = zPredict_sigmaPoint - repmat(zPredict,1,L);
    xll = xPredict_sigmaPoint - repmat(xPredict_linear_hat(:,k),1,L);
    P_zz =  R + wi * (zll * zll');
    P_xz = wi * (xll * zll');
    % kalman gain
    K = P_xz / P_zz;
    
    % correct the state
    xEstimate(:,k) = xPredict_linear_hat(:,k) + K * (Z_degree(:,k) - zPredict);
    % correct the covariance
    pEstimate_temp = pPredict_linear - K * P_zz * K';
    pEstimate(:,k) = reshape(pEstimate_temp,16,1);
end

x_rd(1,:) = sqrt(xEstimate(1,:).^2 + xEstimate(2,:).^2);
x_rd(2,:) = atan(xEstimate(2,:)./xEstimate(1,:));
trueTarget_rd(1,:) = sqrt(trueTarget(2,:).^2 + trueTarget(3,:).^2);
trueTarget_rd(2,:) = atan(trueTarget(3,:)./trueTarget(2,:));
Z_radius = [Z_degree(1,:);Z_degree(2,:)*pi/180];
h = figure;
set(h,'position',[100 100 800 800]);

polarplot(Z_radius(2,:),Z_radius(1,:),'r-o');
hold on;
polarplot(x_rd(2,:),x_rd(1,:),'g-*');
polarplot(trueTarget_rd(2,:),trueTarget_rd(1,:),'b->');
thetalim([0 90]);
rlim([1000 3500]);

%     xPredict_reshape = reshape(xPredict(:,k),4,[]);
%     xPredict_sumSigma_hat(:,k) = wi * sum(xPredict_reshape(:,1:end - 1,2)) + w0 * xPredict_reshape(:,end); % x 的预测