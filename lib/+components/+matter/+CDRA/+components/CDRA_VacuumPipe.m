classdef CDRA_VacuumPipe < matter.procs.f2f
    %PIPE Summary of this class goes here
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
        % Surface roughness of the pipe in [m]
        fRoughness      = 0;
        
        % Pressure drop coefficient of the pipe that can be multiplied with
        % the volumetric flowrate to get the pressure looss
        fDropCoefficient = 0;
        
        % Last time the solverDeltas() method was called
        fTimeOfLastUpdate = -1;
        
        % Current dynamic viscosity
        fDynamicViscosity = 17.2 / 10^6;
        
        % Maximum relative change in temperature or pressure before
        % recalculation of dynamic viscosity is triggered.
        rMaxChange = 0.01;
        
        fTemperatureLastUpdate = 0;
        fPressureLastUpdate    = 0;

    end
    
    %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %-- Methods ----------------------------------------------------------%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods
        %% Constructor
        function this = CDRA_VacuumPipe(oContainer, sName, fLength, fDiameter, fRoughness)

            this@matter.procs.f2f(oContainer, sName);

            this.fLength   = fLength;
            this.fDiameter = fDiameter;
            
            this.supportSolver('hydraulic', fDiameter, fLength);
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
            this.supportSolver('coefficient',  @this.calculatePressureDropCoefficient);

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
                
                if this.oTimer.fTime > this.fTimeOfLastUpdate
                    this.fDynamicViscosity = this.oMT.calculateDynamicViscosity(oFlowIn);
                end
                fFlowSpeed = oFlowIn.fFlowRate/(fDensity*pi*0.25*this.fDiameter^2);

                if oFlowIn.fPressure < 100
                    this.fDeltaPressure = fFlowRate * 1000;
                elseif oFlowIn.fPressure < 1000
                    A = 1 - ((1000 - oFlowIn.fPressure)/900);
                    this.fDeltaPressure = (1-A) * (fFlowRate * 1000) + A*functions.calculateDeltaPressure.Pipe(this.fDiameter, this.fLength,fFlowSpeed, this.fDynamicViscosity, fDensity, this.fRoughness, 0);
                else
                    this.fDeltaPressure = functions.calculateDeltaPressure.Pipe(this.fDiameter, this.fLength,...
                                    fFlowSpeed, this.fDynamicViscosity, fDensity, this.fRoughness, 0);
                end

            end
            
            this.fTimeOfLastUpdate = this.oTimer.fTime;

        end
        
        
        % TO DO: why would a solver want this?
        function fDropCoefficient = calculatePressureDropCoefficient(this, ~)
            % For the laminar, incompressible, multi-branch solver.
            % https://en.wikipedia.org/wiki/Hagen-Poiseuille_equation
            % 
            % The returned coefficient is multiplied with the volumetric
            % flow rate calculated with: Q = m' / rho
            % Q = volumetric flow rate, m' = mass flow rate, rho = density
            % [m^3/s]                   [kg/s]               [kg/m^3]
            %
            % With that, the pressure drop can be calculated:
            % DP = C * Q
            % DP = pressure drop [Pa], C = flow coefficient [Pa / (m^3/s)]
            
            [~] = this.solverDeltas(this.aoFlows(1).fFlowRate);
            fDropCoefficient = this.fDropCoefficient;
            
            this.fTimeOfLastUpdate = this.oTimer.fTime;
            
            %fprintf('%s-%s    eta %f   l %f  d %f  =  %f\n', this.oBranch.sName, this.sName, fDynamicViscosity, this.fLength, this.fDiameter, fDropCoefficient);
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

            % Since the flowrate can have changed without the branch
            % setting the new flowrate, the flow arPartialMass can be
            % outdated (multibranch use case with flow phases). In order to
            % prevent outdated/wrong partial masses we check the in phase
            % partial mass and provide that for the density calculation.
            if fFlowRate >= 0
                iInExme = 1;
            else
                iInExme = 2;
            end
            
            try            
                fDensityIn = oFlowIn.getDensity();
                fDensityOut = oFlowOut.getDensity();
                
                fDensity = (fDensityIn + fDensityOut) / 2;
            catch
                fDensity = this.oBranch.coExmes{iInExme}.oPhase.fDensity;
            end

            fFlowSpeed   = abs(fFlowRate) / ((pi / 4) * this.fDiameter^2 * fDensity);

            % Calculate dynamic viscosity
            if this.oBranch.fFlowRate ~= 0
                try
                    if this.oTimer.fTime > this.fTimeOfLastUpdate
                        rTemperatureChange = abs(1-this.fTemperatureLastUpdate/oFlowIn.fTemperature);
                        rPressureChange    = abs(1-this.fPressureLastUpdate/oFlowIn.fPressure);
                        if rTemperatureChange > this.rMaxChange || rPressureChange > this.rMaxChange
                            this.fDynamicViscosity = oFlowIn.getDynamicViscosity();
                            this.fTemperatureLastUpdate = oFlowIn.fTemperature;
                            this.fPressureLastUpdate    = oFlowIn.fPressure;
                        end
                    end
                catch
                    this.fDynamicViscosity = 17.2 / 10^6;
                
                    if ~base.oDebug.bOff
                        this.out(3,1,'dynamic-viscosity-fall-back','Error calculating dynamic viscosity in pipe (%s - %s). Using default value instead: %f [Pa s].',{this.oBranch.sName, this.sName, this.fDynamicViscosity});
                    end
                end
            else
                this.fDynamicViscosity = 17.2 / 10^6;
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
            if fDensity == 0
                fDeltaPressure = 0;
                return; % Return early.
            end
            if this.fDynamicViscosity == 0
                this.fDynamicViscosity = 17.2 / 10^6;
                
                if ~base.oDebug.bOff
                    this.out(3,1,'dynamic-viscosity-fall-back','Error calculating dynamic viscosity in pipe (%s - %s). Using default value instead: %f [Pa s].',{this.oBranch.sName, this.sName, this.fDynamicViscosity});
                end
            end

            if oFlowIn.fPressure < 100
                fDeltaPressure = fFlowRate * 1000;
            elseif oFlowIn.fPressure < 1000
                A = 1 - ((1000 - oFlowIn.fPressure)/900);
                fDeltaPressure = (1-A) * (fFlowRate * 1000) + A*functions.calculateDeltaPressure.Pipe(this.fDiameter, this.fLength,fFlowSpeed, this.fDynamicViscosity, fDensity, this.fRoughness, 0);
            else
                fDeltaPressure = functions.calculateDeltaPressure.Pipe (this.fDiameter, this.fLength, fFlowSpeed, this.fDynamicViscosity, fDensity, this.fRoughness, 0);
            end
            this.fDeltaPressure = fDeltaPressure;
            
            this.fDropCoefficient = fDeltaPressure / (fFlowSpeed * pi * 0.25 * this.fDiameter^2);
        end

    end

end
