classdef Launch_Sim
    %CROP execution class with manual input
    %    This class is used to test the CROP model with manual input. In
    %    this class there are 4 functions which are "set_parameter",
    %    "set_initial_concentration", "set_pH_activity_model" and "run".
    
    properties
    end
    
    methods (Static = true)
        function set_parameter()
            % This function is used to set the rate constants manually
            % (struct "tReaction"). 
            % V_D is set to zero, as reaction D (equilibrium between NH3 
            % and NH4) is now implented inside the pHLinearSystem model. 
            % Removing reaction D from Enzyme_Reactions would be
            % complicated, therefore this fast solution is used instead. 
           
            K_A = 10.173436;         %m_E^A
            V_A = 0.455;         %n_E^A
            K_B = 10.002983;         %m_E^B
            V_B = 0.278;         %n_E^B
            K_C = 20.013786;         %m_E^C
            V_C = 0.459;         %n_E^C
            V_D = 0;                %k_f^D
            
            % optimized Rate constants in reaction A from Sun's Thesis
            tReaction.A.a.fk_f = K_A * V_A;
            tReaction.A.a.fk_r = V_A;
            tReaction.A.b.fk_f = K_A * V_A;
            tReaction.A.b.fk_r = V_A;
            tReaction.A.c.fk_f = 0.000214;      %a^A
            tReaction.A.c.fk_r = 0.983421;      %b^A
            tReaction.A.d.fk_f = 0.000052;      %c^A
            tReaction.A.d.fk_r = 0.887639;      %d^A
            tReaction.A.e.fk_f = 0.000477;      %m_I^A * n_I^A
            tReaction.A.e.fk_r = 0.000434;      %n_I^A
            tReaction.A.f.fk_f = 0.000477;      %m_I^A * n_I^A
            tReaction.A.f.fk_r = 0.000434;      %n_I^A
            tReaction.A.g.fk_f = K_A * V_A;
            tReaction.A.g.fk_r = V_A;
            tReaction.A.h.fk_f = 0.000477;      %m_I^A * n_I^A
            tReaction.A.h.fk_r = 0.000434;      %n_I^A
            
            
            % optimized Rate constants in reaction D from Sun's Thesis
            tReaction.D.fk_f = V_D; 
            tReaction.D.fk_r = 5.6234e4 * V_D;
            
            % optimized Rate constants in reaction B from Sun's Thesis
            tReaction.B.a.fk_f = K_B * V_B;
            tReaction.B.a.fk_r = V_B;
            tReaction.B.b.fk_f = K_B * V_B;
            tReaction.B.b.fk_r = V_B;
            tReaction.B.c.fk_f = 0.000046;      %a^B
            tReaction.B.c.fk_r = 1.569257;      %b^B
            tReaction.B.d.fk_f = 0.011483;      %c^B
            tReaction.B.d.fk_r = 1.987534;      %d^B
            tReaction.B.e.fk_f = 0.000391;      %m_I^B * n_I^B
            tReaction.B.e.fk_r = 0.000315;      %n_I^B
            tReaction.B.f.fk_f = 0.000391;      %m_I^B * n_I^B
            tReaction.B.f.fk_r = 0.000315;      %n_I^B
            tReaction.B.g.fk_f = K_B * V_B;
            tReaction.B.g.fk_r = V_B;
            tReaction.B.h.fk_f = 0.000391;      %m_I^B * n_I^B
            tReaction.B.h.fk_r = 0.000315;      %n_I^B
            
            
            % optimized Rate constants in reaction C from Sun's Thesis
            tReaction.C.a.fk_f = K_C * V_C;
            tReaction.C.a.fk_r = V_C;
            tReaction.C.b.fk_f = K_C * V_C;
            tReaction.C.b.fk_r = V_C;
            tReaction.C.c.fk_f = 0.000156;      %a^C
            tReaction.C.c.fk_r = 2.793547;      %b^C
            tReaction.C.d.fk_f = 0.001014;      %c^C
            tReaction.C.d.fk_r = 1.995478;      %d^C
            tReaction.C.e.fk_f = 0.001010;      %m_I^C * n_I^C
            tReaction.C.e.fk_r = 0.000509;      %n_I^C
            tReaction.C.f.fk_f = 0.001010;      %m_I^C * n_I^C
            tReaction.C.f.fk_r = 0.000509;      %n_I^C
            tReaction.C.g.fk_f = K_C * V_C;
            tReaction.C.g.fk_r = V_C;
            tReaction.C.h.fk_f = 0.001010;      %m_I^C * n_I^C
            tReaction.C.h.fk_r = 0.000509;      %n_I^C
            
            % Save the set rate constants in the data file "Parameter.mat"
            % in the folder "+components"
            p = mfilename('fullpath');
            [pathstr,~,~] = fileparts(p);
            
            asPath = strsplit(pathstr,'\');
            iLen_Path = length(asPath);
            sPath = strjoin(asPath(1,1:(iLen_Path-1)),'\');
            save([sPath '\+components\Parameter.mat'],'tReaction')
            
            disp('Parameter are already set.')      
        end
        
        function set_initial_concentration(Urea_Percent)
            % This function is used to set the initial concentrations of 
            % the main reactants as well as the concentrations of the 
            % enzymes and inhibitors manually 
            % (struct "tfInitial_Settings").
            
            %optimized initial concentration values for Urea_Percent = 100
            %from Sun's Thesis in mol/L
            tfInitial_Settings.tfConcentration.AE = 5.061421;
            tfInitial_Settings.tfConcentration.AI = 0.000043;
            tfInitial_Settings.tfConcentration.AEI = 0;             %complex has not been formed yet
            tfInitial_Settings.tfConcentration.BE = 5.012552;
            tfInitial_Settings.tfConcentration.BI = 0.114165;
            tfInitial_Settings.tfConcentration.BEI = 0;             %complex has not been formed yet
            tfInitial_Settings.tfConcentration.CE = 5.000041;
            tfInitial_Settings.tfConcentration.CI = 0.000234;
            tfInitial_Settings.tfConcentration.CEI = 0;             %complex has not been formed yet
     
            
            %initial concentrations of the reactants in mol/L
            tfInitial_Settings.tfConcentration.COH4N2   = 0.249770;                             % 450.00 g Urea in 30 L Water
            tfInitial_Settings.tfConcentration.NH3      = 0;                                    % ammonia has not been formed yet
            tfInitial_Settings.tfConcentration.NH4      = (0.87/30);                            % from NH4Cl
            tfInitial_Settings.tfConcentration.Cl       = ((2*0.1+2*0.07+0.12+2.48+0.87)/30);   % from NH4Cl, NaCl, KCl, MgCl2 and CaCl2
            tfInitial_Settings.tfConcentration.NO2      = 0;                                    % nitrite has not been formed yet
            tfInitial_Settings.tfConcentration.NO3      = 0;                                    % nitrate has not been formed yet
            tfInitial_Settings.tfConcentration.C6H5O7   = (0.07/30);                            % from Na3C6H5O7
            tfInitial_Settings.tfConcentration.Na       = ((2.48+2*0.5+3*0.07)/30);             % from Na3C6H5O7, NaCl and Na2So4
            tfInitial_Settings.tfConcentration.SO4      = (0.5/30);                             % from Na2So4
            tfInitial_Settings.tfConcentration.HPO4     = (0.71/30);                            % from K2HPO4
            tfInitial_Settings.tfConcentration.K        = ((2*0.71+0.12)/30);                   % from K2HPO4 and KCl
            tfInitial_Settings.tfConcentration.Mg       = (0.07/30);                            % from MgCl2
            tfInitial_Settings.tfConcentration.Ca       = (0.1/30);                             % from CaCl2
            tfInitial_Settings.tfConcentration.CO3      = 0;                                    % neglecting CO3 in tap water
            tfInitial_Settings.tfConcentration.CaCO3    = 0.166552;                             % from CaCO3, 0.5 kg in total

            % In this thesis, Urea_Percent is always 100%
            
%             if Urea_Percent == 7 % 7% data series
%                 tfInitial_Settings.series = 'H';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 1/60;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 4e-3;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 3e-3;
%                 tfInitial_Settings.fK_Metal_Ion = 800;
%             elseif Urea_Percent == 40 % 40% data series
%                 tfInitial_Settings.series = 'D';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 0.1;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 0.03;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 0.005;
%                 tfInitial_Settings.tfConcentration.CE = 0;
%                 tfInitial_Settings.fK_Metal_Ion = 0;
%             elseif Urea_Percent == 3.5 % 3.5% data series
%                 tfInitial_Settings.series = 'C';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 15e-3;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 0.0025;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 0.002;
%                 tfInitial_Settings.fK_Metal_Ion = 4000;
%             elseif Urea_Percent == 60 % 60% data series
%                 tfInitial_Settings.series = 'E';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 0.2;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 0.02;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 2.5e-3;
%                 tfInitial_Settings.tfConcentration.CE = 0;
%                 tfInitial_Settings.fK_Metal_Ion = 200;
%             elseif Urea_Percent == 80 % 80% data series
%                 tfInitial_Settings.series = 'F';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 0.2;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 0.03;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 2.5e-3;
%                 tfInitial_Settings.tfConcentration.BE = 0.06;
%                 tfInitial_Settings.tfConcentration.CE = 0;
%                 tfInitial_Settings.fK_Metal_Ion = 200;
%             elseif Urea_Percent == 100 % 100% data series
%                 tfInitial_Settings.series = 'G';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 0.1;
%                 tfInitial_Settings.tfConcentration.NH3 = 0;
%                 tfInitial_Settings.tfConcentration.NH4 = 0;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 0;
%                 tfInitial_Settings.fK_Metal_Ion = 0;
%             elseif Urea_Percent == 20 % 20% data series
%                 tfInitial_Settings.series = 'I';
%                 tfInitial_Settings.tfConcentration.CH4N2O = 50e-3;
%                 tfInitial_Settings.tfConcentration.NH3 = 0.01;
%                 tfInitial_Settings.tfConcentration.NH4 = 0.015;
%                 tfInitial_Settings.tfConcentration.NO2 = 0;
%                 tfInitial_Settings.tfConcentration.NO3 = 0;
%                 tfInitial_Settings.fK_Metal_Ion = 5000;
%             end
            
            % Save the set initial concentrations in the data file "Initial_Settings.mat"
            % in the folder "+components"
            p = mfilename('fullpath');
            [pathstr,~,~] = fileparts(p);
            
            asPath = strsplit(pathstr,'\');
            iLen_Path = length(asPath);
            sPath = strjoin(asPath(1,1:(iLen_Path-1)),'\');
            save([sPath '\+components\Initial_Settings.mat'],'tfInitial_Settings')
            
            disp(['The input urine solution is ' num2str(Urea_Percent) '%.'])
            disp('Initial concentrations for COH4N2, NH3, NH4, NO2 and NO3 are already set.')
        end
        
        function set_pH_activity_model()
            % This function is used to create the pH activity model (struct "tpH_Diagram").
            
            % "tfpH_low" is the struct which contains the left edge of the pH
            % activity curve of each enzyme reaction (A, B, C).
            % "tfpH_high" is the struct which contains the right edge of the pH
            % activity curve of each enzyme reaction (A, B, C).
            % "tfpH_opt" is the struct which contains the optimum of the pH
            % activity curve of each enzyme reaction (A, B, C).
            % "tiCurve_Mode" describes the shape of the pH activity curve.
            tfpH_low.A  = 1+3;
            tfpH_opt.A  = 6+3;
            tfpH_high.A = 11+3;
            tfpH_low.B  = 1+3;
            tfpH_opt.B  = 6+3;
            tfpH_high.B = 11+3;
            tfpH_low.C  = 1+3;
            tfpH_opt.C  = 6+3;
            tfpH_high.C = 11+3;
            tiCurve_Mode.A = 3;
            tiCurve_Mode.B = 6;
            tiCurve_Mode.C = 2;
            
            % Create the vectors of pH values in the pH activity model of
            % each enzyme reaction (A, B, C) which are accordance with the
            % x_pH^A, x_pH^B, x_pH^C in Fig.4-18 in Sun's thesis
            for i = 1:11
                for j =['A' 'B' 'C']
                    if i<=6
                        tpH_Diagram.(j).fpH(i) = ((tfpH_opt.(j) - tfpH_low.(j))/5) * (i - 1) + tfpH_low.(j);
                    else
                        tpH_Diagram.(j).fpH(i) = ((tfpH_high.(j) - tfpH_opt.(j))/5) * (i - 6) + tfpH_opt.(j);
                    end
                end
            end
            
            
            % Create the vectors of pH effect factors in the pH activity model of
            % each enzyme reaction (A, B, C) with respect to "tiCurve_Mode" 
            % which are accordance with the y_Factor^A, y_Factor^B, y_Factor^C 
            % in Fig.4-18 in Sun's thesis
            for j = ['A' 'B' 'C']
                if tiCurve_Mode.(j) == 1 % Curve Mode 1 : general clock curve
                    tpH_Diagram.(j).rFactor(1) = 0;
                    tpH_Diagram.(j).rFactor(2) = 0.1;
                    tpH_Diagram.(j).rFactor(3) = 0.48;
                    tpH_Diagram.(j).rFactor(4) = 0.9;
                    tpH_Diagram.(j).rFactor(5) = 0.99;
                    tpH_Diagram.(j).rFactor(6) = 1;
                    tpH_Diagram.(j).rFactor(7) = 0.99;
                    tpH_Diagram.(j).rFactor(8) = 0.9;
                    tpH_Diagram.(j).rFactor(9) = 0.48;
                    tpH_Diagram.(j).rFactor(10) = 0.1;
                    tpH_Diagram.(j).rFactor(11) = 0;
                elseif tiCurve_Mode.(j) == 2 % Curve Mode 2 : for reaction C in this thesis
                    tpH_Diagram.(j).rFactor(1) = 0;
                    tpH_Diagram.(j).rFactor(2) = 1;
                    tpH_Diagram.(j).rFactor(3) = 1;
                    tpH_Diagram.(j).rFactor(4) = 1;
                    tpH_Diagram.(j).rFactor(5) = 0.4;
                    tpH_Diagram.(j).rFactor(6) = 0.2;
                    tpH_Diagram.(j).rFactor(7) = 0.1;
                    tpH_Diagram.(j).rFactor(8) = 0.05;
                    tpH_Diagram.(j).rFactor(9) = 0.025;
                    tpH_Diagram.(j).rFactor(10) = 0;
                    tpH_Diagram.(j).rFactor(11) = 0;
                elseif tiCurve_Mode.(j) == 3 % Curve Mode 3 : for reaction A in this thesis
                    tpH_Diagram.(j).rFactor(1) = 0;
                    tpH_Diagram.(j).rFactor(2) = 0;
                    tpH_Diagram.(j).rFactor(3) = 0;
                    tpH_Diagram.(j).rFactor(4) = 1;
                    tpH_Diagram.(j).rFactor(5) = 1;
                    tpH_Diagram.(j).rFactor(6) = 1;
                    tpH_Diagram.(j).rFactor(7) = 1;
                    tpH_Diagram.(j).rFactor(8) = 1;
                    tpH_Diagram.(j).rFactor(9) = 1;
                    tpH_Diagram.(j).rFactor(10) = 1;
                    tpH_Diagram.(j).rFactor(11) = 0;
                elseif tiCurve_Mode.(j) == 4 % Curve Mode 4 : all range active
                    tpH_Diagram.(j).rFactor(1) = 1;
                    tpH_Diagram.(j).rFactor(2) = 1;
                    tpH_Diagram.(j).rFactor(3) = 1;
                    tpH_Diagram.(j).rFactor(4) = 1;
                    tpH_Diagram.(j).rFactor(5) = 1;
                    tpH_Diagram.(j).rFactor(6) = 1;
                    tpH_Diagram.(j).rFactor(7) = 1;
                    tpH_Diagram.(j).rFactor(8) = 1;
                    tpH_Diagram.(j).rFactor(9) = 1;
                    tpH_Diagram.(j).rFactor(10) = 1;
                    tpH_Diagram.(j).rFactor(11) = 1;
                elseif tiCurve_Mode.(j) == 5 % Curve Mode 5 : for reaction B backup
                    tpH_Diagram.(j).rFactor(1) = 0;
                    tpH_Diagram.(j).rFactor(2) = 0;
                    tpH_Diagram.(j).rFactor(3) = 1;
                    tpH_Diagram.(j).rFactor(4) = 1;
                    tpH_Diagram.(j).rFactor(5) = 0.4;%1;
                    tpH_Diagram.(j).rFactor(6) = 0.1;%1;
                    tpH_Diagram.(j).rFactor(7) = 0;%1;
                    tpH_Diagram.(j).rFactor(8) = 0;%1;
                    tpH_Diagram.(j).rFactor(9) = 0;%1;
                    tpH_Diagram.(j).rFactor(10) = 0;%1;
                    tpH_Diagram.(j).rFactor(11) = 0;%1;
                elseif tiCurve_Mode.(j) == 6 % Curve Mode 6 : for reaction B in this thesis
                    tpH_Diagram.(j).rFactor(1) = 0;
                    tpH_Diagram.(j).rFactor(2) = 0;
                    tpH_Diagram.(j).rFactor(3) = 1;
                    tpH_Diagram.(j).rFactor(4) = 1;
                    tpH_Diagram.(j).rFactor(5) = 1;
                    tpH_Diagram.(j).rFactor(6) = 1;
                    tpH_Diagram.(j).rFactor(7) = 1;
                    tpH_Diagram.(j).rFactor(8) = 1;
                    tpH_Diagram.(j).rFactor(9) = 1;
                    tpH_Diagram.(j).rFactor(10) = 0;
                    tpH_Diagram.(j).rFactor(11) = 0;
                end
            end
            
            % Save the set pH activity model in the data file "pH_model.mat"
            % in the folder "+components"
            p = mfilename('fullpath');
            [pathstr,~,~] = fileparts(p);
            
            asPath = strsplit(pathstr,'\');
            iLen_Path = length(asPath);
            sPath = strjoin(asPath(1,1:(iLen_Path-1)),'\');
            save([sPath '\+components\pH_model.mat'],'tpH_Diagram')
            
            disp('pH activity model is already set.')
        end
        
        function run(Urea_Percent)
            % This function is used to execute the CROP model with the
            % manual inputs.
            components.matter.CROP.execution.Launch_Sim.set_parameter();
            components.matter.CROP.execution.Launch_Sim.set_pH_activity_model()
            components.matter.CROP.execution.Launch_Sim.set_initial_concentration(Urea_Percent);
            vhab.exec('scph.CROP.setup_Verification');
        end
    end
    
end

