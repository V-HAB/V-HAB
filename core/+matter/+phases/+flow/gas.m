classdef gas < matter.phases.flow.flow
    %% gas_flow_node
    % A gas phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'gas';
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
        function this = gas(oStore, sName, tfMasses, fVolume, fTemperature)
            %% gas flow node constructor
            % 
            % creates a new gas flow node which is modelled as containing
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
            % fVolume       : Just an informative value, as it is not
            %                 actually used in calculations
            % fTemperature  : Temperature of matter in phase
            
            this@matter.phases.flow.flow(oStore, sName, tfMasses, fVolume, fTemperature);
            
            this.fVirtualPressure = this.fMass * this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
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
                afPartsPerMillion = this.oMT.calculatePartsPerMillion(this);
            end
        end
    end
end

