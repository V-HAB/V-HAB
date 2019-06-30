classdef manual
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
           
            K_A = 1.2;
            V_A = 0.05;
            K_B = 1;
            V_B = 0.025;
            K_C = 3;
            V_C = 0.018;
            V_D = 0.005;
            
            % Rate constants in reaction A
            tReaction.A.a.fk_f = K_A * V_A;
            tReaction.A.a.fk_r = V_A;
            tReaction.A.b.fk_f = K_A * V_A;
            tReaction.A.b.fk_r = V_A;
            tReaction.A.c.fk_f = 0.005;
            tReaction.A.c.fk_r = 0.003;
            tReaction.A.d.fk_f = 0.005;
            tReaction.A.d.fk_r = 0.003;
            tReaction.A.e.fk_f = 0.01;
            tReaction.A.e.fk_r = 0.05;
            tReaction.A.f.fk_f = 0.01;
            tReaction.A.f.fk_r = 0.05;
            tReaction.A.g.fk_f = K_A * V_A;
            tReaction.A.g.fk_r = V_A;
            tReaction.A.h.fk_f = 0.1;
            tReaction.A.h.fk_r = 0.5;
            
            
            % Rate constants in reaction D
            tReaction.D.fk_f = V_D; 
            tReaction.D.fk_r = 5.6234e4 * V_D;
            
            % Rate constants in reaction B
            tReaction.B.a.fk_f = K_B * V_B;
            tReaction.B.a.fk_r = V_B;
            tReaction.B.b.fk_f = K_B * V_B;
            tReaction.B.b.fk_r = V_B;
            tReaction.B.c.fk_f = 0.005;
            tReaction.B.c.fk_r = 0.003;
            tReaction.B.d.fk_f = 0.005;
            tReaction.B.d.fk_r = 0.003;
            tReaction.B.e.fk_f = 0.005;
            tReaction.B.e.fk_r = 0.003;
            tReaction.B.f.fk_f = 0.05;
            tReaction.B.f.fk_r = 0;
            tReaction.B.g.fk_f = K_B * V_B;
            tReaction.B.g.fk_r = V_B;
            tReaction.B.h.fk_f = 0.5;
            tReaction.B.h.fk_r = 0;
            
            
            % Rate constants in reaction C
            tReaction.C.a.fk_f = K_C * V_C;
            tReaction.C.a.fk_r = V_C;
            tReaction.C.b.fk_f = K_C * V_C;
            tReaction.C.b.fk_r = V_C;
            tReaction.C.c.fk_f = 0.005;
            tReaction.C.c.fk_r = 0.003;
            tReaction.C.d.fk_f = 0.005;
            tReaction.C.d.fk_r = 0.003;
            tReaction.C.e.fk_f = 0.005;
            tReaction.C.e.fk_r = 0.003;
            tReaction.C.f.fk_f = 0.05;
            tReaction.C.f.fk_r = 0;
            tReaction.C.g.fk_f = K_C * V_C;
            tReaction.C.g.fk_r = V_C;
            tReaction.C.h.fk_f = 0.5;
            tReaction.C.h.fk_r = 0;
            
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
            % the main reactants as well as the metal ion balance constant 
            % and ammonia vaporization concentration manually 
            % (struct "tfInitial_Settings").
            
            tfInitial_Settings.tfConcentration.AE = 0.1;
            tfInitial_Settings.tfConcentration.AI = 0;
            tfInitial_Settings.tfConcentration.AEI = 0;
            tfInitial_Settings.tfConcentration.BE = 0.1;
            tfInitial_Settings.tfConcentration.BI = 0;
            tfInitial_Settings.tfConcentration.BEI = 0;
            tfInitial_Settings.tfConcentration.CE = 0.1;
            tfInitial_Settings.tfConcentration.CI = 0;
            tfInitial_Settings.tfConcentration.CEI = 0;
            tfInitial_Settings.fCon_NH3_Vapor = 0.012;
            

            if Urea_Percent == 7 % 7% data series
                tfInitial_Settings.series = 'H';
                tfInitial_Settings.tfConcentration.CH4N2O = 1/60;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 4e-3;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 3e-3;
                tfInitial_Settings.fK_Metal_Ion = 800;
            elseif Urea_Percent == 40 % 40% data series
                tfInitial_Settings.series = 'D';
                tfInitial_Settings.tfConcentration.CH4N2O = 0.1;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 0.03;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 0.005;
                tfInitial_Settings.tfConcentration.CE = 0;
                tfInitial_Settings.fK_Metal_Ion = 0;
            elseif Urea_Percent == 3.5 % 3.5% data series
                tfInitial_Settings.series = 'C';
                tfInitial_Settings.tfConcentration.CH4N2O = 15e-3;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 0.0025;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 0.002;
                tfInitial_Settings.fK_Metal_Ion = 4000;
            elseif Urea_Percent == 60 % 60% data series
                tfInitial_Settings.series = 'E';
                tfInitial_Settings.tfConcentration.CH4N2O = 0.2;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 0.02;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 2.5e-3;
                tfInitial_Settings.tfConcentration.CE = 0;
                tfInitial_Settings.fK_Metal_Ion = 200;
            elseif Urea_Percent == 80 % 80% data series
                tfInitial_Settings.series = 'F';
                tfInitial_Settings.tfConcentration.CH4N2O = 0.2;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 0.03;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 2.5e-3;
                tfInitial_Settings.tfConcentration.BE = 0.06;
                tfInitial_Settings.tfConcentration.CE = 0;
                tfInitial_Settings.fK_Metal_Ion = 200;
            elseif Urea_Percent == 100 % 100% data series
                tfInitial_Settings.series = 'G';
                tfInitial_Settings.tfConcentration.CH4N2O = 0.1;
                tfInitial_Settings.tfConcentration.NH3 = 0;
                tfInitial_Settings.tfConcentration.NH4OH = 0;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 0;
                tfInitial_Settings.fK_Metal_Ion = 0;
            elseif Urea_Percent == 20 % 20% data series
                tfInitial_Settings.series = 'I';
                tfInitial_Settings.tfConcentration.CH4N2O = 50e-3;
                tfInitial_Settings.tfConcentration.NH3 = 0.01;
                tfInitial_Settings.tfConcentration.NH4OH = 0.015;
                tfInitial_Settings.tfConcentration.HNO2 = 0;
                tfInitial_Settings.tfConcentration.HNO3 = 0;
                tfInitial_Settings.fK_Metal_Ion = 5000;
            end
            
            % Save the set initial concentrations in the data file "Initial_Settings.mat"
            % in the folder "+components"
            p = mfilename('fullpath');
            [pathstr,~,~] = fileparts(p);
            
            asPath = strsplit(pathstr,'\');
            iLen_Path = length(asPath);
            sPath = strjoin(asPath(1,1:(iLen_Path-1)),'\');
            save([sPath '\+components\Initial_Settings.mat'],'tfInitial_Settings')
            
            disp(['The input urine solution is ' num2str(Urea_Percent) '%.'])
            disp('Initial concentrations for CH4N2O, NH3, NH4OH, HNO2 and HNO3 are already set.')
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
            % x_pH^A, x_pH^B, x_pH^C in Fig.4-18 in the thesis
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
            % in Fig.4-18 in the thesis
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
            suyi.CROP.execution.manual.set_parameter();
            suyi.CROP.execution.manual.set_pH_activity_model()
            suyi.CROP.execution.manual.set_initial_concentration(Urea_Percent);
            vhab.exec('suyi.CROP.setup');
        end
    end
    
end
