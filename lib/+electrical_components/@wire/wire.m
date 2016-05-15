classdef wire < electrical.components.resistor
    %WIRE Summary of this class goes here
    %   Detailed explanation goes here

    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Properties -------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Constant = true)

        % For reynolds number calculation
        Const = struct(...
            'fReynoldsCritical', 2320 ...
        );

    end

    properties (SetAccess = public, GetAccess = public)
        % Length, diameter in [m]
        fLength   = 0;
        fDiameter = 0;
    end

    properties (SetAccess = protected, GetAccess = public)
        % Surface roughness of the pipe in [?]
        fRoughness      = 0;
        
        % Pressure differential caused by the pipe in [Pa]
        fDeltaPressure  = 0;

    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = wire(oContainer, sName, fLength, fDiameter, fRoughness)

            this@electrical.components.resistor(oContainer, sName);

            this.fLength   = fLength;
            this.fDiameter = fDiameter;
            
            this.supportSolver('hydraulic', fDiameter, fLength);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            

            if nargin >= 5
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

                fFlowSpeed = oFlowIn.fFlowRate/(fDensity*pi*0.25*this.fDiameter^2);

                this.fDeltaPressure = pressure_loss_pipe(this.fDiameter, this.fLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);
            end

        end
        
        %% Update function for callback solver
        function fDeltaPressure = solverDeltas(this, fFlowRate)
            
            % No flow rate, no  pressure drop, no work. Just return that
            % and quit. 
            if (fFlowRate == 0)
                fDeltaPressure = 0;
                return;
            end

            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);

            % Average pressure
            fAveragePressure = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;

            % No pressure at all ... normally just return, drop zero
            if fAveragePressure == 0

                fDeltaPressure = 0; % no pressure? -> no pressure drop!
                                 % FR (kg/s) should be small compared to
                                 % drop, so send that?
                return;

            end

            % Calculate density and flow speed
            try
                % As for the pressure above, we are using the average
                % density between in- and outflow.
                %fDensityIn = this.oMT.calculateDensity(oFlowIn);
                %fDensityOut = this.oMT.calculateDensity(oFlowOut);
                fDensityIn = oFlowIn.getDensity();
                fDensityOut = oFlowOut.getDensity();
                
                fDensity = (fDensityIn + fDensityOut) / 2;
            catch
                %TODO solver should handle that, could also be an issue if
                %     temperature is zero
                fMolarMass = sif(oFlowIn.fMolarMass > 0, oFlowIn.fMolarMass, 1);

                %CHECK e.g. fRoh - used for fV and Re - so doesn't really make
                %      sense to include. Need another way to calculate Re/V?
                fDensity = (fAveragePressure * fMolarMass) / (this.oMT.Const.fUniversalGas * oFlowIn.fTemperature);
                this.warn('solverDeltas',['Something went wrong in the density calculation for a pipe (%s on branch %s). \n',...
                                          'If this happened during initialization, it should be alright. Otherwise\n',...
                                          'please check if the branch is configured properly.'], this.sName, this.oBranch.sName);
            end
            fFlowSpeed   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fDensity);

            % Calculate dynamic viscosity
            try
                %fEta = this.oMT.calculateDynamicViscosity(oFlowIn);
                fEta = oFlowIn.getDynamicViscosity();
            catch
                fEta = 17.2 / 10^6;
            end

            % If the pipe diameter is zero, no matter can flow through that
            % pipe. Return an infinite pressure drop which should let the
            % solver know to set the flow rate to zero.
            if (this.fDiameter == 0)
                fDeltaPressure = Inf;
                return; % Return early.
            end

            % If the dynamic viscosity or the density is empty, return zero
            % as the pressure drop. Else, the pressure drop may become NaN.
            if (fDensity == 0) || (fEta == 0)
                fDeltaPressure = 0;
                return; % Return early.
            end

            % Reynolds Number
            fReynolds = fFlowSpeed * this.fDiameter * fDensity / fEta;
            % Interpolate transition between turbulent and laminar
            %CHECK What does this do?
            pInterp = 0.1;


            % Calculating the Darcy-Weisbach friction factor using the
            % Colebrook equation for use in transient and turbulent flow
            % regimes.
            fLambdaColebrook = 0;

            if (this.Const.fReynoldsCritical * (1 - pInterp) < fReynolds)
                fLambdaColebrook = colebrook(fReynolds, this.fRoughness);
            end


            % (PDF) Laminar: Hagen-Poiseuille
            if fReynolds <= this.Const.fReynoldsCritical * (1 - pInterp)

                % Darcy friction factor for laminar flow in a circular pipe
                % (Reynolds number less than 2320) is given by the 
                % following formula:
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

            %CHECK EQUATIONS friction factor! Colebrook valid for all Re numbers?D
            %   http://www.brighthubengineering.com/hydraulics-civil-engineering/55227-pipe-flow-calculations-3-the-friction-factor-and-frictional-head-loss/
            %   http://www.efunda.com/formulae/fluids/calc_pipe_friction.cfm#friction
            %   http://eprints.iisc.ernet.in/9587/1/Friction_Factor_for_Turbulent_Pipe_Flow.pdf
            %   http://www.engineeringtoolbox.com/colebrook-equation-d_1031.html
            % all smooth - blasius: fLambda = 0.3164 / fReynolds^(1/4)
            % Prantl: fLambda = 1 / (1.8 * log(Re / 7))^2

            fDeltaPressure = fDensity / 2 * fFlowSpeed^2 * (fLambda * this.fLength / this.fDiameter);
            
            this.fDeltaPressure = fDeltaPressure;

            %CHECK include test for choked flow, i.e. speed at outlet > speed of sound?
            %      should that be done by the f2f comp or the solver? Include attribute
            %      fFlowArea in f2fs so solver can use flow rate, density and area to calculate speed?
        end

    end

end
