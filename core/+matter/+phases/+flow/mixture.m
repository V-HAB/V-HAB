classdef mixture < matter.phases.flow.flow
    %% mixture_flow_node
    % A mixture phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'mixture';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Actual phase type of the matter in the phase, e.g. 'liquid',
        % 'solid' or 'gas'.
        sPhaseType;
        
        bGasPhase = false;
    end
    
    properties (Dependent)
        % Partial pressures [Pa]
        afPP;
        
        % Relative humidity in the phase
        rRelHumidity;
    
        % Substance concentrations in ppm. This is a dependent property because it is
        % only calculated on demand because it should rarely be used. if
        % the property is used often, making it not a dependent property or
        % providing a faster calculation option is suggested
        afPartsPerMillion;
    end
    
    methods
        function this = mixture(oStore, sName, sPhaseType, tfMass, fTemperature, fPressure)
            %% mixture flow node constructor    
            % 
            % creates a new mixture flow node which is modelled as containing
            % no mass. The fMass property of the phase must still be
            % present for implementation purposes, but it will not change
            % from it's initial value.
            % Ideally a flow node is used together with a multibranch
            % solver to calculate the pressure of the phase as flow nodes
            % are considered very small phases.
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fTemperature  : Temperature of matter in phase
            % fPressure     : Pressure of the phase
            
            % Note that the volume passed on here of 1e-6 is only a
            % momentary volume to enable the definition of the phase. This
            % value is overwriten by the calculation:
            % this.fVolume = this.fMass / this.fDensity;
            % within this constructor!
            this@matter.phases.flow.flow(oStore, sName, tfMass, 1e-6, fTemperature);
            
            if strcmp(sPhaseType, 'gas')
                this.bGasPhase = true;
            end
            
            this.sPhaseType = sPhaseType;
            if nargin > 5
                this.fVirtualPressure = fPressure;
            else
                this.fVirtualPressure = 1e5;
            end
            this.updatePressure();
            
            this.fDensity = this.oMT.calculateDensity(this);
            this.fVolume = this.fMass / this.fDensity;
            
        end
        function afPP = get.afPP(this)
            if this.oMultiBranchSolver.bUpdateInProgress
                this.throw('FlowPhase:UnsafeAccess:afPP',                             ...
                    ['You are trying to access the afPP property of the flow phase ', ...
                     '%s during an iteration of the multi-branch solver. ',           ...
                     'This can lead to incorrect results. Please use the flow ',      ...
                     'information from the appropriate matter.flow object. ',         ...
                     'It is set by the solver and updated every iteration.'], this.sName);
            else
                if ~this.bGasPhase
                    error('phase:mixture:invalidAccessPartialPressures', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
                end
                afPartialMassFlow_In = zeros(this.iProcsEXME, this.oMT.iSubstances);
                
                for iExme = 1:this.iProcsEXME
                    fFlowRate = this.coProcsEXME{iExme}.iSign * this.coProcsEXME{iExme}.oFlow.fFlowRate;
                    if fFlowRate > 0
                        afPartialMassFlow_In(iExme,:) = this.coProcsEXME{iExme}.oFlow.arPartialMass .* fFlowRate;
                    end
                end
                
                % See ideal gas mixtures for information on this
                % calculation: "Ideally the ratio of partial pressures
                % equals the ratio of the number of molecules. That is, the
                % mole fraction of an individual gas component in an ideal
                % gas mixture can be expressed in terms of the component's
                % partial pressure or the moles of the component"
                afCurrentMolsIn   = (sum(afPartialMassFlow_In, 1) ./ this.oMT.afMolarMass);
                arFractions       = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPartialPressure = arFractions .*  this.fPressure;
                
                afPartialPressure(isnan(afPartialPressure)) = 0;
                afPartialPressure(afPartialPressure < 0 ) = 0;
                
                afPP = afPartialPressure;
            end
        end
        
        function rRelHumidity = get.rRelHumidity(this)
            if this.oMultiBranchSolver.bUpdateInProgress
                this.throw('FlowPhase:UnsafeAccess:rRelHumidity',                     ...
                    ['You are trying to access the afPP property of the flow phase ', ...
                     '%s during an iteration of the multi-branch solver. ',           ...
                     'This can lead to incorrect results. Please use the flow ',      ...
                     'information from the appropriate matter.flow object. ',         ...
                     'It is set by the solver and updated every iteration.'], this.sName);
            else
                if ~this.bGasPhase
                    error('phase:mixture:invalidAccessHumidity', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
                end
                % Check if there is water in here at all
                if this.afPP(this.oMT.tiN2I.H2O)
                    % calculate saturation vapour pressure [Pa];
                    fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                    % calculate relative humidity
                    rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
                else
                    rRelHumidity = 0;
                end
            end
        end
        function afPartsPerMillion = get.afPartsPerMillion(this)
            % Calculates the PPM value on demand.
            % Made this a dependent variable to reduce the computational
            % load during run-time since the value is rarely used. 
            if this.oMultiBranchSolver.bUpdateInProgress
                this.throw('FlowPhase:UnsafeAccess:afPartsPerMillion',                     ...
                    ['You are trying to access the afPartsPerMillion property of the flow phase ', ...
                     '%s during an iteration of the multi-branch solver. ',           ...
                     'This can lead to incorrect results. Please use the flow ',      ...
                     'information from the appropriate matter.flow object. ',         ...
                     'It is set by the solver and updated every iteration.'], this.sName);
            else
                if ~this.bGasPhase
                    error('phase:mixture:invalidAccessPartsPerMillion', 'you are trying to access a gas property in a mixture phase that is not set a gas type!')
                end
                afPartsPerMillion = this.oMT.calculatePartsPerMillion(this);
            end
        end
    end
end

