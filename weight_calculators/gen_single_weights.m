% Simple script that extracts the covariance matrices for the entire band
% and computes Y-factors

close all;
clearvars;

tic;
% System parameters
Dir = '/lustre/projects/flag/'; % '/lustre/projects/flag/TMP/BF'; %'/lustre/gbtdata/TGBT16A_508_01/TMP/BF';
projID = 'AGBT16B_400_04';
sub_dir = '/BF';
save_dir = sprintf('%s/%s/%s', Dir, projID, sub_dir);

% May 24th, 2017 - 05  %%%%%% GBT test %%%%%%
% Quant gain = 10
on_tstamp = {'2017_05_28_05:39:03'};
off_tstamp = {'2017_05_28_05:39:52'};

overwrite = 1;

good_idx = [20,21,23:33,35:39];
bad_freqs = [81:100,181:200,281:300,381:400,481:500];

% Off Pointing
fprintf('Getting OFF pointing from %s...\n', off_tstamp{1});
tmp_stmp = off_tstamp{1};
filename = sprintf('%s/mat/%s.mat', save_dir, tmp_stmp);

if ~exist(filename, 'file') || overwrite == 1
    [R, az_off, el_off] = aggregate_banks_onebeam(save_dir, projID, tmp_stmp);
    save(filename, 'R', 'az_off', 'el_off');
else
    load(filename);
end
Roff = R(good_idx, good_idx, :);

% ON pointing
fprintf('Getting ON pointing from %s...\n', on_tstamp{1});
tmp_stmp = on_tstamp{1};

filname = sprintf('%s/mat/%s.mat', save_dir, tmp_stmp);
if ~exist(filename, 'file') || overwrite == 1
    [R, az, el] = aggregate_banks_onebeam(save_dir, projID, tmp_stmp);
    save(filename, 'R', 'az', 'el');
else
    load(filename);
end

Ron = R(good_idx, good_idx, :);

Nele = size(Ron, 1);
Nele_act = size(R,1);
Nbins = size(Ron, 3);

w = single_beam(Ron, Roff, Nbins, good_idx, bad_freqs);

N_beam = 7;
N_ele= 64;
N_bin = 25;
N_pol = 2;
weights = zeros(N_ele, N_bin, N_beam, N_pol);
for i = 1:7
    weights(:,:,i,1) = w;
    weights(:,:,i,2) = w;
end

% Save data into weight file formatted for RTBF code
banks = {'A', 'B', 'C', 'D',...
    'E', 'F', 'G', 'H',...
    'I', 'J', 'K', 'L',...
    'M', 'N', 'O', 'P',...
    'Q', 'R', 'S', 'T'};

interleaved_w = zeros(2*N_ele*N_bin*N_beam*N_pol,1);
weight_dir = sprintf('%s/weight_files', Dir);
chan_idx = [1:5, 101:105, 201:205, 301:305, 401:405];

for b = 1:length(banks)
    % Get bank name
    bank_name = banks{b};

    % Extract channels for bank
    w1 = weights(:,chan_idx+5*(b-1),:,:);
    
    % Reshape for file format
    w2 = reshape(w1, N_ele*N_bin, N_beam*N_pol);
    w_real = real(w2(:));
    w_imag = imag(w2(:));
    interleaved_w(1:2:end) = w_real(:);
    interleaved_w(2:2:end) = w_imag(:);
    
    % Get filename
    weight_file = sprintf('%s/w_%s_%s.bin', weight_dir, on_tstamp{1}, bank_name);
    weight_file = strrep(weight_file, ':', '_');
    
    % Create metadata for weight file
    offsets_el = el;
    offsets_az = az;
    offsets = [offsets_el; offsets_az; offsets_el; offsets_az; offsets_el; offsets_az; offsets_el; offsets_az; offsets_el; offsets_az; offsets_el; offsets_az; offsets_el; offsets_az];
    offsets = offsets(:);
    cal_filename = sprintf('%s%s.fits',on_tstamp{1}, banks{b});
    to_skip1 = 64 - length(cal_filename);
    algorithm_name = 'Max Signal-to-Noise Ratio';
    to_skip2 = 64 - length(algorithm_name);
    xid = b-1;
    
    % Write to binary file
    WID = fopen(weight_file,'wb');
    if WID == -1
        error('Author:Function:OpenFile', 'Cannot open file: %s', weight_file);
    end
    
    % Write payload
    fwrite(WID, single(interleaved_w), 'single');
    
    % Write metadata
    fwrite(WID,single(offsets),'float');
    fwrite(WID,cal_filename, 'char*1');
    if to_skip1 > 0
        fwrite(WID, char(zeros(1,to_skip1)));
    end
    fwrite(WID,algorithm_name, 'char*1');
    if to_skip2 > 0
        fwrite(WID, char(zeros(1,to_skip2)));
    end
    fwrite(WID, uint64(xid), 'uint64');
    fclose(WID);
    
    fprintf('Saved to %s\n', weight_file);
end

toc; 

