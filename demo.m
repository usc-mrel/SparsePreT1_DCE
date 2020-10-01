% This is the demo script of Sparse Pre-Contrast T1 Mapping for
% High-Resolution Whole-Brain DCE-MRI
clear; clc; close all;

addpath(genpath('./DRO'));
addpath(genpath('./Utils'));

%% Data preparation and reconstruction settings
load('noisecov.mat');
load('discreteBrainModel.mat');
load('coilSenseMaps.mat');

% Set scan parameters and reconstruction related options
FA                      = 1.5 * 10.^((0:6)./6);
B1                      = ones(size(Mo));
TR                      = 0.0049;
opt.FA                  = FA;
opt.tr                  = TR;
opt.class               = 'single';
opt.FTdim               = [1 2];
opt.FTshift             = 1;

% Synthesize fully sampled kspace data and VFA images
k                       = genKspace(Mo, 1./T1, B1, FA, TR, sMaps, [1 2], 1);
img                     = spgr(Mo, 1./T1, B1, FA, TR);

[np, nv, ns, nt, nr]    = size(k);
opt.B1                  = B1;
opt.S                   = repmat(sMaps, [1 1 ns nt 1]);
opt.size                = [np nv ns nt nr];
opt.MaxIter             = 500;

%%
SNR = inf; % SNR level
for realization = 1 % Noise realization loop
    wm                  = img(:, :, :, 7) .* (imData == tissueTypes.WhiteMatter);
    k_noise             = applyNoise(k, wm(abs(wm) ~= 0), noisecov, SNR);
    for pattern = [0 1 2 3] % Pattern loop
        for R = [1 4 7 10 16 22 28 34 40] % Undersampling level loop
            fprintf(['Reconstructing SNR: ' num2str(SNR) ', pattern: ' num2str(pattern) ', R: ' num2str(R) '\n']);
            % Apply k-space under-sampling. "pattern' controls the type of pattern and
            % "R" controls under-sampling level.
            [kU, U]     = applyU(k_noise, pattern, R, 1);
            opt.U       = U;
            
%             tmp1        = spgr(ones(1,1,2), ones(1,1,2)/1.5, 1, opt.FA, opt.tr);
%             tmp2        = sum(conj(sMaps).*iFastFT(kU, opt), 5);
%             wm          = tmp2.*(imData==3); % WM signal
%             wm          = wm(abs(wm~=0));
%             sf2         = median(tmp1(:))/median(abs(wm));
            sf2         = 1.5922;
            kU          = kU * sf2; % Data normalization.
            
            % Direct T1 mapping
            mo          = zeros(np, nv, ns);
            r1          = ones(np, nv, ns);
            P           = cat(4, mo, r1);
            
            [mo, r1]    = P_SEN(P, kU, opt);
            mo          = mo/sf2;
            t1          = 1./r1;
            
            % Save results
            switch pattern
                case 0
                    matname = ['.\results\SNR' num2str(SNR) '_SP_rect_R' num2str(R) '_re' num2str(realization) '.mat'];
                case 1
                    matname = ['.\results\SNR' num2str(SNR) '_SP_ellip_R' num2str(R) '_re' num2str(realization) '.mat'];
                case 2
                    matname = ['.\results\SNR' num2str(SNR) '_RGA_ellip_R' num2str(R) '_re' num2str(realization) '.mat'];
                case 3
                    matname = ['.\results\SNR' num2str(SNR) '_RGA_rect_R' num2str(R) '_re' num2str(realization) '.mat'];
            end
            save(matname, 'mo', 'r1', 't1', 'U');
        end
    end
end

%% Display results
load('T1cm.mat');
mask = (imData ~= 0);
figure;
montage(permute(mask.*Mo, [1 2 4 3]), 'DisplayRange', [0 1.5], 'Size', [3 4]);
title('Ground truth M_0');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);

figure;
montage(permute(1e3*mask.*T1, [1 2 4 3]), 'DisplayRange', [0 3e3], 'Size', [3 4]);
colormap(T1colormap);
c2 = colorbar;
c2.Position = [0.92 0.15 0.03 0.75];
c2.Label.String = 'ms';
c2.Label.Position = [1.4 3200 0];
c2.Label.Rotation = 0;
title('Ground truth T_1');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);
 
figure;
montage(permute(mask.*mo, [1 2 4 3]), 'DisplayRange', [0 1.5], 'Size', [3 4]);
title('Reconstructed M_0');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);

figure;
montage(permute(1e3*mask.*t1, [1 2 4 3]), 'DisplayRange', [0 3e3], 'Size', [3 4]);
c4 = colorbar;
c4.Position = [0.92 0.15 0.03 0.75];
c4.Label.String = 'ms';
c4.Label.Position = [1.4 3200 0];
c4.Label.Rotation = 0;
colormap(T1colormap);
colormap(T1colormap);
title('Reconstructed T_1');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);

figure;
montage(permute(100*mask.*(Mo-mo)./Mo, [1 2 4 3]), 'DisplayRange', [-20 20], 'Size', [3 4]);
c5 = colorbar;
c5.Position = [0.92 0.15 0.03 0.75];
c5.Label.String = '%';
c5.Label.Position = [1.4 22.66 0];
c5.Label.Rotation = 0;
title('M_0 fractional difference');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);

figure;
montage(permute(100*mask.*abs(T1-t1)./T1, [1 2 4 3]), 'DisplayRange', [0 15], 'Size', [3 4]);
c6 = colorbar;
c6.Position = [0.92 0.15 0.03 0.75];
c6.Label.String = '%';
c6.Label.Position = [1.4 16 0];
c6.Label.Rotation = 0;
colormap(T1colormap);
colormap(T1colormap);
title('T_1 fractional difference');
set(gca, 'Position', [0.0959 0.0581 0.8076 0.8433]);