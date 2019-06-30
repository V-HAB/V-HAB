function  Set_Parameter_in_Fitting( afPmr_Estimate, sSeries )
%This function is used to set parameters in each data series for data fitting.

% Get the corresponding sequence of the data series in the parameter set
[iSequence, ~] = suyi.CROP.tools.Settings_DataSeries_in_Fitting(sSeries);

% Rate constants for enzyme reaction A, B and C which are describe in
% section 4.3.3 in the thesis
j = 0;
for i = ['A' 'B' 'C']
    tReaction.(i).a.fk_f = afPmr_Estimate(1+8*j) * afPmr_Estimate(2+8*j); % mE * nE
    tReaction.(i).a.fk_r = afPmr_Estimate(2+8*j); % mE
    tReaction.(i).b.fk_f = afPmr_Estimate(1+8*j) * afPmr_Estimate(2+8*j); % mE * nE
    tReaction.(i).b.fk_r = afPmr_Estimate(2+8*j); % mE
    tReaction.(i).c.fk_f = afPmr_Estimate(5+8*j); % a
    tReaction.(i).c.fk_r = afPmr_Estimate(6+8*j); % b
    tReaction.(i).d.fk_f = afPmr_Estimate(7+8*j); % c
    tReaction.(i).d.fk_r = afPmr_Estimate(8+8*j); % d
    tReaction.(i).e.fk_f = afPmr_Estimate(3+8*j) * afPmr_Estimate(4+8*j); % mI * nI
    tReaction.(i).e.fk_r = afPmr_Estimate(4+8*j); % mI
    tReaction.(i).f.fk_f = afPmr_Estimate(3+8*j) * afPmr_Estimate(4+8*j); % mI * nI
    tReaction.(i).f.fk_r = afPmr_Estimate(4+8*j); % mI
    tReaction.(i).g.fk_f = afPmr_Estimate(1+8*j) * afPmr_Estimate(2+8*j); % mE * nE
    tReaction.(i).g.fk_r = afPmr_Estimate(2+8*j); % mE
    tReaction.(i).h.fk_f = afPmr_Estimate(3+8*j) * afPmr_Estimate(4+8*j); % mI * nI
    tReaction.(i).h.fk_r = afPmr_Estimate(4+8*j); % mI
    j = j + 1;
end

% Reaction rates for enzyme reaction D
tReaction.D.fk_f = afPmr_Estimate(25);
tReaction.D.fk_r = 5.6234e4 * afPmr_Estimate(25);

% NH3 vaporization concentration
tfInitial_Settings.fCon_NH3_Vapor = afPmr_Estimate(26);

% Parameter for specific data series
tfInitial_Settings.series = sSeries;

tfInitial_Settings.tfConcentration.CH4N2O = afPmr_Estimate(26+1+12*iSequence);
tfInitial_Settings.tfConcentration.NH3    = afPmr_Estimate(26+2+12*iSequence);
tfInitial_Settings.tfConcentration.NH4OH  = afPmr_Estimate(26+3+12*iSequence);
tfInitial_Settings.tfConcentration.HNO2   = afPmr_Estimate(26+4+12*iSequence);
tfInitial_Settings.tfConcentration.HNO3   = afPmr_Estimate(26+5+12*iSequence);
tfInitial_Settings.tfConcentration.AE     = afPmr_Estimate(26+6+12*iSequence);
tfInitial_Settings.tfConcentration.BE     = afPmr_Estimate(26+7+12*iSequence);
tfInitial_Settings.tfConcentration.CE     = afPmr_Estimate(26+8+12*iSequence);
tfInitial_Settings.tfConcentration.AI     = afPmr_Estimate(26+9+12*iSequence);
tfInitial_Settings.tfConcentration.BI     = afPmr_Estimate(26+10+12*iSequence);
tfInitial_Settings.tfConcentration.CI     = afPmr_Estimate(26+11+12*iSequence);
tfInitial_Settings.fK_Metal_Ion           = afPmr_Estimate(26+12+12*iSequence);

% The concentration of EI is always set 0
tfInitial_Settings.tfConcentration.AEI = 0;
tfInitial_Settings.tfConcentration.BEI = 0;
tfInitial_Settings.tfConcentration.CEI = 0;

 % Save the set parameters in the corresponding data files 
 % in the folder "+components"
sFullpath = mfilename('fullpath');
[sFile,~,~] = fileparts(sFullpath);
asFile_Path = strsplit(sFile,'\');
iLen_File_Path = length(asFile_Path);
sPath = strjoin(asFile_Path(1,1:(iLen_File_Path-1)),'\');
save([sPath '\+components\Initial_Settings.mat'],'tfInitial_Settings')
save([sPath '\+components\Parameter.mat'],'tReaction')
disp(['The input urine solution is ' sSeries])
disp('Initial concentrations for CH4N2O, NH3, NH4OH, HNO2 and HNO3 are already set.')
disp('Parameter are already set.')

end

