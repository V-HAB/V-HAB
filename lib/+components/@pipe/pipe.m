classdef pipe < matter.procs.f2f
    %PIPE Summary of this class goes here
    %   Detailed explanation goes here

    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Properties -------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Constant = true)

        % For reynolds number calculation
        Const = struct(...
            'fReynoldsCritical', 2300 ...
        );

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


        fLastLambda     = 0.08;

    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = pipe(oMT, sName, fLength, fDiameter, fRoughness)

            this@matter.procs.f2f(oMT, sName);

            this.fLength   = fLength;
            this.fDiameter = fDiameter;
            
            this.supportSolver('hydraulic', fDiameter, fLength);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            

            if nargin == 5
               this.fRoughness = fRoughness;
            end

        end
        
        %% Update function for hydraulic solver
        function update(this)

            bZeroFlows = 0;
            for k = 1:length(this.aoFlows)
                if this.aoFlows(1,k).fFlowRate == 0
                   bZeroFlows = 1;
                end
            end

            if bZeroFlows == 0
                [oFlowIn, ~ ]=this.getFlows();

                fDensity = this.oMT.calculateDensity(oFlowIn);

                fDynamicViscosity = this.oMT.calculateDynamicViscosity(oFlowIn);

                fFlowSpeed = oFlowIn.fFlowRate/(fDensity*pi*0.25*this.fHydrDiam^2);

                this.fDeltaPressure = pressure_loss_pipe(this.fHydrDiam, this.fHydrLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);

                this.fDeltaPress = this.fDeltaPressure;
            end

        end
        
        %% Update function for callback solver
        function fDeltaPress = solverDeltas(this, fFlowRate)
            
            % No flow rate, no  pressure drop, no work. Just return that
            % and quit. 
            if (fFlowRate == 0)
                fDeltaPress = 0;
                return;
            end

            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);

            % Average pressure
            fAveragePressure = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;

            % No pressure at all ... normally just return, drop zero
            if fAveragePressure == 0

                fDeltaPress = 1; % 0 not good for solver ... :)
                                 % FR (kg/s) should be small compared to
                                 % drop, so send that?
                return;

            % No pressure on 'in' side? Just use 'out' side ...?
            elseif oFlowIn.fPressure == 0

                %CHECK1
                %oFlowIn = oFlowOut;

            end

            % Calculate density and flow speed
            try
                fDensity = this.oMT.calculateDensity(oFlowIn);
            catch
                %TODO solver should handle that, could also be an issue if
                %     temperature is zero
                fMolMass = sif(oFlowIn.fMolMass > 0, oFlowIn.fMolMass, 1);
                %CHECK e.g. fRoh - used for fV and Re - so doesn't really make
                %      sense to include. Need another way to calculate Re/V?
                fDensity = (fAveragePressure * fMolMass / 1000) / (matter.table.Const.fUniversalGas * oFlowIn.fTemp);
            end
            fFlowSpeed   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fDensity);

            % Calculate dynamic viscosity
            try
                fEta = this.oMT.calculateDynamicViscosity(oFlowIn);
            catch
                fEta = 17.2 / 10^6;
            end

            % Reynolds Number
            fReynolds = fFlowSpeed * this.fDiameter * fDensity / fEta;
            % Interpolate transition between turbulent and laminar
            %CHECK What does this do?
            pInterp = 0.1;


            % TEST - calculate Colebrook and use for transient /
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
            elseif (this.Const.fReynoldsCritical * (1 - pInterp) < fReynolds) && (fReynolds <= this.Const.fReynoldsCritical * (1 + pInterp))

                fLambdaLaminar  = 64 / fReynolds;
                fLambdaTurbulent = fLambdaColebrook;
                pInterp = (-this.Const.fReynoldsCritical * (1 - pInterp) + fReynolds) / (this.Const.fReynoldsCritical * 2 * pInterp);
                fLambda = fLambdaLaminar + (fLambdaTurbulent - fLambdaLaminar) * pInterp;

            else
                fLambda = fLambdaColebrook;
            end

            %CHECK EQUATIONS friction factor! DROP at blas>prandtl
            %   http://www.brighthubengineering.com/hydraulics-civil-engineering/55227-pipe-flow-calculations-3-the-friction-factor-and-frictional-head-loss/
            %   http://www.efunda.com/formulae/fluids/calc_pipe_friction.cfm#friction
            %   http://eprints.iisc.ernet.in/9587/1/Friction_Factor_for_Turbulent_Pipe_Flow.pdf
            %   http://www.engineeringtoolbox.com/colebrook-equation-d_1031.html
            % HERE: all smooth, just blasius?

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

            fDeltaPress = fDensity / 2 * fFlowSpeed^2 * (fLambda * this.fLength / this.fDiameter);

            %TODO check V2 (output speed -> pressure at output + FR) ==> if
            %     CHOKED (>= speed of sound) -> increase deltaP accordingly

        end

    end

end
