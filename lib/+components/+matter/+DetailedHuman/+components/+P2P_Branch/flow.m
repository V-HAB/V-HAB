classdef flow < matter.flow
    
    properties (SetAccess = protected, GetAccess = public)
        % The following three properties capture the pressure, temperature
        % and partial mass state of the flow through this p2p. This is done
        % in an effort to reduce the calls to calculateSpecificHeatCapacity
        % in the matter table. See setMatterProperties() for details.
        fPressureLastHeatCapacityUpdate;
        fTemperatureLastHeatCapacityUpdate;
        arPartialMassLastHeatCapacityUpdate;
        
        fSpecificHeatCapacityP2P = 0;
    end
    
    methods
        function this = flow(oBranch)
            this@matter.flow(oBranch);
        end
        function setMatterPropertiesBranch(this, afFlowRates)
            
            fFlowRate     = sum(afFlowRates);
            
            if fFlowRate == 0
                arPartialMass = zeros(1,this.oMT.iSubstances);
            else
                arPartialMass = afFlowRates/fFlowRate;
            end
            
            %CHECK see setData, using the IN exme props!
            if this.fFlowRate >= 0
                oPhase = this.oIn.oPhase;
            else
                oPhase = this.oOut.oPhase;
            end
            
            fTemperature   = oPhase.fTemperature;
            fPressure      = oPhase.fPressure;
            
            this.setMatterProperties(fFlowRate, arPartialMass, fTemperature, fPressure);
        end
        
        % The set matter properties function should only be called by the
        % update function of this class. However, since it has to override
        % the setMatterProperties function from its superclass matter.flow
        % the access rights cannot be set to private. Usually the p2p
        % updates are called  by the phase massupdates, therefore making it
        % unnecessary for the P2Ps to call the massupdates. However, in
        % some use cases (e.g. the manual P2P) it is not the phase
        % massupdate which triggers recalculations for the P2Ps. To prevent
        % these cases from accidentially performing invalid operations,
        % this access restriction is necessary.
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemperature, fPressure)
            %% setMatterProperties
            % is the function used by the update function to actually set
            % the new partial mass flow rates of the P2P
            %
            % Optional Inputs:
            % fFlowRate:     The current total flowrate of the p2p in kg/s.
            %                Total means it must be the sum of all partial
            %                mass flow rates
            % arPartialMass: Vector containing the partial mass flow ratios
            %                to convert fFlowRate into a vector with
            %                partial mass flows by using fFlowRate *
            %                arPartialMass
            % fTemperature:  The temperature for the flow of the P2P mass
            %                transfer
            % fPressure:     The pressure for the flow of the P2P mass
            %                transfer
            %
            % If no value is provided for any of the inputs the value of
            % the ingoing Exme is used based on the fFlowRate. If fFlowRate
            % is not provided the current property fFlowRate is used
            
            % Checking for the presence of the fFlowRate input argument
            if (nargin < 2) || isempty(fFlowRate)
                fFlowRate = this.fFlowRate; 
            else
                this.fFlowRate = fFlowRate;
            end
            
            % We use the sign of the flow rate to determine the exme from
            % which we take the matter properties
            if fFlowRate >= 0
                oExme = this.oIn;
            else
                oExme = this.oOut;
            end
            
            % Checking for the presence of the arPartialMass input argument
            if nargin < 3 || isempty(arPartialMass)
                this.arPartialMass = oExme.oPhase.arPartialMass;
            else
                this.arPartialMass = arPartialMass;
            end
            
            % Checking for the presence of the fTemperature input argument
            if nargin > 3
                bNoTemperature = isempty(fTemperature);
            else
                bNoTemperature = true;
            end
            
            % Checking for the presence of the fPressure input argument
            if nargin > 4
                bNoPressure = isempty(fPressure);
            else
                bNoPressure = true;
            end
            
            % If temperature or pressure are not given, we get those values
            % from the inflowing exme.
            if nargin < 4 || bNoTemperature || bNoPressure
                [ fExMePressure, fExMeTemperature ] = oExme.getExMeProperties();
            end
            
            % Setting the fTemperature property
            if (nargin < 4) || bNoTemperature
                this.fTemperature = fExMeTemperature; 
            else
                this.fTemperature = fTemperature;
            end
            
            % Setting the fPressure property
            if (nargin < 5) || bNoPressure
                this.fPressure = fExMePressure; 
            else
                this.fPressure = fPressure;
            end
                
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            this.oIn.oPhase.registerMassupdate();
            this.oOut.oPhase.registerMassupdate();
            
            % If the flow rate is zero, 
            if this.fFlowRate == 0
                this.fSpecificHeatCapacityP2P = 0;
                return;
            end
            
            afMass = this.arPartialMass .* this.fFlowRate;
            
            this.fMolarMass = this.oMT.calculateMolarMass(afMass);
            
            if isempty(this.fPressureLastHeatCapacityUpdate) ||...
               (abs(this.fPressureLastHeatCapacityUpdate - this.fPressure) > 100) ||...
               (abs(this.fTemperatureLastHeatCapacityUpdate - this.fTemperature) > 1) ||...
               (max(abs(this.arPartialMassLastHeatCapacityUpdate - this.arPartialMass)) > 0.01)
           
                % Calculating the number of mols for each species
                afMols = afMass ./ this.oMT.afMolarMass; 

                % Calculating the total number of mols
                fGasAmount = sum(afMols);

                % Calculating the partial amount of each species by mols
                arFractions = afMols ./ fGasAmount;

                % Calculating the partial pressures by multiplying with the
                % total pressure in the phase
                afPartialPressures = arFractions .* this.fPressure;
                
                afMass = this.oMT.resolveCompoundMass(afMass, this.oIn.oPhase.arCompoundMass);
                
                this.fSpecificHeatCapacityP2P = this.oMT.calculateSpecificHeatCapacity(oExme.oPhase.sType, afMass, this.fTemperature, afPartialPressures);
                
                this.fPressureLastHeatCapacityUpdate     = this.fPressure;
                this.fTemperatureLastHeatCapacityUpdate  = this.fTemperature;
                this.arPartialMassLastHeatCapacityUpdate = this.arPartialMass;
            end
        end
    end
end

