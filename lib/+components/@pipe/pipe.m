classdef pipe < solver.matter.iterative.procs.f2f
    %PIPE Summary of this class goes here
    %   Detailed explanation goes here

    properties (Constant = true)
        % For reynolds number calculation
% <<<<<<< Updated upstream
%         C = struct(...
%             'fEta', 17.2, ...   % [10^6 Pa s]
%             'Re_c', 2300 * 1.1 ...   % [10^6 Pa s] - should be 2040?
% =======
        Const = struct(...
            'fReynoldsCritical', 2300 ...
        );
% >>>>>>> Stashed changes

    end

    properties (SetAccess = public, GetAccess = public)
        % Length, diameter in [m]
        fLength   = 0;
        fDiameter = 0;
    end

    properties (SetAccess = protected, GetAccess = public)
        fHydrDiam;
        fHydrLength;
        bActive         = false;

        fDeltaTemp      = 0;
        fDeltaPressure  = 0;
        fDeltaPress     = 0;
        fRoughness      = 0;


        fLastLambda = 0.08;

    end

    methods
        function  this = pipe(oMT, sName, fLength, fDiameter, fRoughness)
            %this@solver.basic.matter.procs.f2f(oMT, sName);
            this@solver.matter.iterative.procs.f2f(oMT, sName);
            %this@matter.procs.f2f(oMT, sName);

            this.fLength   = fLength;
            this.fDiameter = fDiameter;

            % Linear solver
            this.fHydrDiam   = fDiameter;
            this.fHydrLength = fLength;

            if nargin == 5
               this.fRoughness = fRoughness;
            end



            %this.toSolver.hydraulic
            %this.oSolvers
            %this.oHydraulic = solver.matter.basic.proc.f2f.hydraulic(0.005, 1, false);
            %this.oEquation  = x^2l
            %this.oMethod    = solver.matter.basic.proc.f2f.method(@this.calcDrop);
            %
            % method needs access to this obj e.g. for roughness etc
        end

        function update(this)
            bZeroFlows = 0;
            for k = 1:length(this.aoFlows)
                if this.aoFlows(1,k).fFlowRate == 0
                   bZeroFlows = 1;
                end
            end
            if bZeroFlows == 0
                [oFlowIn, ~ ]=this.getFlows();

                %fix matter values required to use the correlations for
                %density and pressure.

% <<<<<<< Updated upstream
%                 %TO DO make dependant on matter table
%                 %values for water
%                 %density at one fixed datapoint
%                 fFixDensity = 998.21;        %g/dm???
%                 %temperature for the fixed datapoint
%                 fFixTemperature = 293.15;           %K
%                 %Molar Mass of the compound
%                 fMolMassH2O = 18.01528;       %g/mol
%                 %critical temperature
%                 fCriticalTemperature = 647.096;         %K
%                 %critical pressure
%                 fCriticalPressure = 220.64*10^5;      %N/m??? = Pa
%
%                 %boiling point normal pressure
%                 fBoilingPressure = 1.01325*10^5;      %N/m??? = Pa
%                 %normal boiling point temperature
%                 fBoilingTemperature = 373.124;      %K
%
%                 fDensity = solver.matter.fdm_liquid.functions.LiquidDensity(InFlow.fTemp,...
%                                     InFlow.fPressure, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
%                                     fCriticalPressure, fBoilingPressure, fBoilingTemperature);
% =======
%                 %TO DO make dependant on matter table
%                 %values for water
%                 %density at one fixed datapoint
%                 fFixDensity = 998.21;        %g/dm?
%                 %temperature for the fixed datapoint
%                 fFixTemperature = 293.15;           %K
%                 %Molar Mass of the compound
%                 fMolMassH2O = 18.01528;       %g/mol
%                 %critical temperature
%                 fCriticalTemperature = 647.096;         %K
%                 %critical pressure
%                 fCriticalPressure = 220.64*10^5;      %N/m? = Pa
%
%                 %boiling point normal pressure
%                 fBoilingPressure = 1.01325*10^5;      %N/m? = Pa
%                 %normal boiling point temperature
%                 fBoilingTemperature = 373.124;      %K

%                 fDensity = solver.matter.fdm_liquid.functions.LiquidDensity(oFlowIn.fTemp,...
%                                     oFlowIn.fPressure, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
%                                     fCriticalPressure, fBoilingPressure, fBoilingTemperature);
%
                fDensity = this.oMT.calculateDensity(oFlowIn);

                fDynamicViscosity = this.oMT.calculateDynamicViscosity(oFlowIn);
% >>>>>>> Stashed changes

                fFlowSpeed = oFlowIn.fFlowRate/(fDensity*pi*0.25*this.fHydrDiam^2);

                this.fDeltaPressure = pressure_loss_pipe(this.fHydrDiam, this.fHydrLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);

                this.fDeltaPress = this.fDeltaPressure;
            end


        end

        function [ fDeltaPress, fDeltaTemp ] = solverDeltas(this, fFlowRate)
            fDeltaTemp  = 0;

%             if ~(this.oBranch.oContainer.oData.oTimer.fTime >= 0)
%                 fDeltaPress = 0;
%                 return;
%             end

            if (fFlowRate == 0)
                fDeltaPress = 0;
                return;
            end

            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);

            % Average pressure
            fAveragePressure = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;

            % No pressure at all ... normally just return, drop zero
% <<<<<<< Updated upstream
            if fAveragePressure == 0
                fDeltaPress = 1; % 0 not good for solver ... :)
                                 % FR (kg/s) should be small compared to
                                 % drop, so send that?
% =======
%             if fAveragePressure == 0
%                 fDeltaPress = 0;
% >>>>>>> Stashed changes
                return;

            % No pressure on 'in' side? Just use 'out' side ...?
            elseif oFlowIn.fPressure == 0
                %CHECK1
                %keyboard();
                %oFlowIn = oFlowOut;
            end

% <<<<<<< Updated upstream
%             %disp(oFlowIn.fMolMass);
%             % No molecular mass? Just use 1?
%             fMolMass = sif(oFlowIn.fMolMass > 0, oFlowIn.fMolMass, 1);
%
%             % Calculate density and flow speed
%             %TODO do with matter.table
%             %CHECK e.g. fRoh - used for fV and Re - so doesn't really make
%             %      sense to include. Need another way to calculate Re/V?
%             fRoh = (fP * fMolMass / 1000) / (matter.table.C.R_m * oFlowIn.fTemp);
%             fV   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fRoh);
%
%
%             % Reynolds
%             Re     = fV * this.fDiameter * fRoh / (this.C.fEta / 10^6);
%             lambda = 0;


%             % If the connected flows are empty, density zero -> speed Inf
%             if isinf(fV)
%                 % Assume Re = 1 --> calculate speed? Density??
%                 %this.warn('solverDeltas', [ 'Speed Inf!' ]);
%                 fV = 0;
%                 Re = 1;
%             end % laminar for initial step


            %disp(num2str(Re));
% =======
            % Calculate density and flow speed
            try
                fDensity = this.oMT.calculateDensity(oFlowIn);
            catch oErr
                fMolMass = sif(oFlowIn.fMolMass > 0, oFlowIn.fMolMass, 1);
                %CHECK e.g. fRoh - used for fV and Re - so doesn't really make
                %      sense to include. Need another way to calculate Re/V?
                fDensity = (fAveragePressure * fMolMass / 1000) / (matter.table.Const.fUniversalGas * oFlowIn.fTemp);
            end
            fFlowSpeed   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fDensity);

            % Calculate dynamic viscosity
            try
                fEta = this.oMT.calculateDynamicViscosity(oFlowIn);
            catch oErr
                fEta = 17.2 / 10^6;
            end
% >>>>>>> Stashed changes

            % Reynolds Number
            fReynolds = fFlowSpeed * this.fDiameter * fDensity / fEta;
            fLambda = 0;
            %keyboard();
            % Interpolate transition between turbulent and laminar
            %CHECK What does this do?
            pInterp = 0.1;


            % TEST - calculate Colebrook and use for transient /
            % turbulent
            this.fRoughness  = 0; %Equivalent sand roughness
            fLambdaColebrook = 0;

            if (this.Const.fReynoldsCritical * (1 - pInterp) < fReynolds)
                fLambdaColebrook = colebrook(fReynolds, this.fRoughness);
            end




            % (PDF) Laminar: Hagen-Poiseuille
            if fReynolds <= this.Const.fReynoldsCritical * (1 - pInterp)
                %CHECK Where does the number 64 come from?
                fLambda = 64 / fReynolds;

            % Interpolation between laminar and turbulent
% <<<<<<< Updated upstream
%             elseif (this.C.Re_c * (1 - pInterp) < Re) && (Re <= this.C.Re_c * (1 + pInterp))
%                 lambda_lam  = 64 / Re;
% %                 lambda_turb = 0.3164 / Re^(1/4);
%                 lambda_turb = fLambdaColebrook;
%
%                 pInterp = (-this.C.Re_c * (1 - pInterp) + Re) / (this.C.Re_c * 2 * pInterp);
%                 %keyboard();
%                 lambda = lambda_lam + (lambda_turb - lambda_lam) * pInterp;
% =======
            elseif (this.Const.fReynoldsCritical * (1 - pInterp) < fReynolds) && (fReynolds <= this.Const.fReynoldsCritical * (1 + pInterp))


                fLambdaLaminar  = 64 / fReynolds;
                fLambdaTurbulent = fLambdaColebrook;
                pInterp = (-this.Const.fReynoldsCritical * (1 - pInterp) + fReynolds) / (this.Const.fReynoldsCritical * 2 * pInterp);
                fLambda = fLambdaLaminar + (fLambdaTurbulent - fLambdaLaminar) * pInterp;
% >>>>>>> Stashed changes


            else
                fLambda = fLambdaColebrook;
            end

            %CHECK EQUATIONS friction factor! DROP at blas>prandtl
            %   http://www.brighthubengineering.com/hydraulics-civil-engineering/55227-pipe-flow-calculations-3-the-friction-factor-and-frictional-head-loss/
            %   http://www.efunda.com/formulae/fluids/calc_pipe_friction.cfm#friction
            %   http://eprints.iisc.ernet.in/9587/1/Friction_Factor_for_Turbulent_Pipe_Flow.pdf
            %   http://www.engineeringtoolbox.com/colebrook-equation-d_1031.html
            % HERE: all smooth, just blasius?

% <<<<<<< Updated upstream
%             %(PDF) Turbulent: Blasius
%             elseif (this.C.Re_c * (1 + pInterp) < Re) && (Re <= 10^5)
%                 lambda = 0.3164 / Re^(1/4);
%                 %lambda = 1 / (1.8 * log(Re / 7))^2;
%
%                 %disp('turb_blas');
%
%             % (PPT) Turbulent: Prantl
%             elseif (10^5 < Re) && (Re < 10^8)
%                 %ISSUE using the Blasius (smooth) flow equation - Prandtl
%                 %      actually produced LOWER lambdas --> WAAAY to high
%                 %      flow rates!!
%                 lambda = 0.3164 / Re^(1/4);
%                 %lambda = 1 / (1.8 * log(Re / 7))^2;
%
%                 %disp('turb_pra');
%
%             else
%                 this.warn('solverDeltas', [ 'Reynolds ' num2str(Re) ' not covered!' ]);
%
%                 % Just assume prantl * 2
%                 %lambda = 1 / (1.8 * log(Re / 7))^2 * 10;
%                 lambda = 0.3164 / Re^(1/4);
%
%                 %if isnan(Re), keyboard(); end;
%             end
% =======
%             %(PDF) Turbulent: Blasius
%             elseif (this.Const.fReynoldsCritical * (1 + pInterp) < fReynolds) && (fReynolds <= 10^5)
%                 fLambda = 0.3164 / fReynolds^(1/4);
%                 %lambda = 1 / (1.8 * log(Re / 7))^2;
%
%             % (PPT) Turbulent: Prantl
%             elseif (10^5 < fReynolds) && (fReynolds < 10^8)
%                 %ISSUE using the Blasius (smooth) flow equation - Prandtl
%                 %      actually produced LOWER lambdas --> WAAAY to high
%                 %      flow rates!!
%                 fLambda = 0.3164 / fReynolds^(1/4);
%                 %lambda = 1 / (1.8 * log(Re / 7))^2;
%
%             else
%                 this.warn('solverDeltas', [ 'Reynolds ' num2str(fReynolds) ' not covered!' ]);
%
%                 % Just assume prantl * 2
%                 fLambda = 1 / (1.8 * log(fReynolds / 7))^2 * 10;
%
%             end
% >>>>>>> Stashed changes

            fDeltaPress = fDensity / 2 * fFlowSpeed^2 * (fLambda * this.fLength / this.fDiameter);

            %TODO check V2 (output speed -> pressure at output + FR) ==> if
            %     CHOKED (>= speed of sound) -> increase deltaP accordingly

        end
    end

end
