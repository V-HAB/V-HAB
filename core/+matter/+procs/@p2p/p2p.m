classdef p2p < matter.flow
    %P2P or Phase to Phase processor, can be used to move matter from one
    % phase to another within a single store. Allows phase change and
    % specific substance transfer to model e.g. condensation/vaporization
    % (phase change) or adsorbing only CO2 from air (consisting of N2, O2,
    % CO2 and H2O)
    
    properties (SetAccess = protected, GetAccess = public)
        fLastUpdate = -1;
        
        % for the thermal side the P2Ps are not different from branches,
        % therefore no thermal P2P exists and instead a thermal branch is
        % used to model the heat transfer of this P2P
        oThermalBranch;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % Name of the p2p processor
        sName;
        
        % Index of the update post tick in the corresponding cell
        % and boolean array of the timer
        hBindPostTickUpdate;
        
        coExmes;
    end
    
    
    
    methods
        function this = p2p(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut)
            % p2p constructor.
            %
            % Parameters:
            %   - sName                 Name of the processor
            %   - sPhaseAndPortIn and sPhaseAndPortOut:
            %       Combination of Phase and Exme name in dot notation:
            %       phase.exme as a string. The in side is considered from
            %       the perspective of the P2P, which means in goes into
            %       the P2P but leaves the phase, which might be confusing
            %       at first. So for a positive flowrate the mass is taken
            %       from the in phase and exme!
            
            % Parent constructor
            this@matter.flow(oStore);
            
            % Phases / ports
            [ sPhaseIn,  sPortIn ]  = strtok(sPhaseAndPortIn, '.');
            [ sPhaseOut, sPortOut ] = strtok(sPhaseAndPortOut, '.');
            
            % Find the phases
            try
                oPhaseIn    = this.oStore.toPhases.(sPhaseIn);
                oPhaseOut   = this.oStore.toPhases.(sPhaseOut);
            catch
                this.throw('p2p', 'Phase could not be found: in phase "%s", out phase "%s"', sPhaseIn, sPhaseOut);
            end
            
            % Set name of P2P
            this.sName   = sName;
            
            % Can only be done after this.oStore is set, store checks that!
            this.oStore.addP2P(this);
            
            
            % If no port is given in sPaseAndPortIn or -Out, auto-create
            % EXMEs, else add the flow to the given (by name) EXME
            if isempty(sPortIn)
                sPortIn = sprintf('.p2p_%s_in', this.sName);
                
                sPhaseType = oPhaseIn.sType;
                
                matter.procs.exmes.(sPhaseType)(oPhaseIn, sPortIn(2:end));
            end
            
            if isempty(sPortOut)
                sPortOut = sprintf('.p2p_%s_out', this.sName);
                
                sPhaseType = oPhaseOut.sType;
                
                matter.procs.exmes.(sPhaseType)(oPhaseOut, sPortOut(2:end));
            end
            
            oPhaseIn.toProcsEXME.(sPortIn(2:end) ).addFlow(this);
            oPhaseOut.toProcsEXME.(sPortOut(2:end)).addFlow(this);
            
            %% Construct asscociated thermal branch
            % Create the respective thermal interfaces for the thermal
            % branch
            % Split to store name / port name
            oPort = this.oStore.getPort(sPortIn(2:end));
            thermal.procs.exme(oPort.oPhase.oCapacity, sPortIn(2:end));
            
            oPort = this.oStore.getPort(sPortOut(2:end));
            thermal.procs.exme(oPort.oPhase.oCapacity, sPortOut(2:end));
            
            % Now we automatically create a fluidic processor for the
            % thermal heat transfer bound to the matter transferred by the
            % P2P
            try
                thermal.procs.conductors.fluidic(this.oStore.oContainer, this.sName, this);
                sCustomName = this.sName;
            % The operation can fail because the P2Ps are local within a
            % store and therefore can share common names acros multiple
            % stores (e.g. you can have 5 Stores, each containing a P2P
            % called "Absorber"). However, as F2Fs the thermal conductors
            % are added to the parent system, and therefore must be unique
            % for each system. Therefore we count a number up until we find
            % a name that is not yet taken for the fluidic processor
            catch oError 
                if contains(oError.message, 'already exists.')
                    bError = true;
                    iCounter = 2;
                    while bError == true
                        % now we just try the name until we find one that
                        % is not yet taken, increasing the counter each
                        % time the creation of the proc failed
                        try
                            thermal.procs.conductors.fluidic(this.oStore.oContainer, [this.sName, '_', num2str(iCounter)], this);
                            bError = false;
                        catch oError
                            if contains(oError.message, 'already exists.')
                                iCounter = iCounter + 1;
                            else
                                % If it is another error than what we area looking for,
                                % we do throw the error
                                this.throw('P2P', oError.message)
                            end
                        end
                        
                        % If we reach 1000 Iterations, throw an error as we
                        % are not likely to find a valid name anymore
                        if iCounter >= 1000
                            this.throw('P2P',[ 'could not find a valid name for the thermal fluidic conductor of P2P ', this.sName])
                        end
                    end
                    sCustomName = [this.sName, '_', num2str(iCounter)];
                else
                    % If it is another error than what we area looking for,
                    % we do throw the error
                    this.throw('P2P', oError.message)
                end
            end
            
            % Now we generically create the corresponding thermal branch
            % using the previously created fluidic conductor
            this.oThermalBranch = thermal.branch(this.oStore.oContainer, [this.oStore.sName,  sPortIn] , {sCustomName}, [this.oStore.sName,  sPortOut], sCustomName, this);
            
            this.coExmes = {this.oIn, this.oOut};
            
            %% Register the post tick update for the P2P at the timer
            this.hBindPostTickUpdate      = this.oTimer.registerPostTick(@this.update,      'matter' , 'P2Ps');
        end
    end
    
    
    
    %% Methods required for the matter handling
    methods
        
        function oExme = getInEXME(this)
            % Little bit of a fake method. The p2p sets the oBranch attri-
            % bute to itself. By implementing this method, the flow can get
            % the inflowing phase properties through the according EXME.
            % This is needed to e.g. get the phase type for heat capacity
            % calculations.
            %TODO: reword
            if this.fFlowRate < 0; oExme = this.oOut; else; oExme = this.oIn; end
        end
        
        
        function exec(this, fTime)
            % Called from subsystem to update the internal state of the
            % processor, e.g. change efficiencies etc
        end
        
        function registerUpdate(this)
            this.hBindPostTickUpdate();
        end
            
        function update(this, fFlowRate, arPartials)
            % Calculate new flow rate in [kg/s]. The update method is
            % called right before the phases merge/extract. The p2p merge
            % or extract is done after the merge of the 'outer' flows and
            % before the extract of those takes places.
            % Therefore, at the point of p2p extraction, the whole (tempo-
            % rary) mass flowing through the phase within that time step is
            % stored in the phase.
            % An absolute value for mass extraction has to be divided by
            % the fTimeStep parameter to get a flow.
            % In case of flow through the filter volume >> the mass within,
            % the in/out flow rates can be used for absorption flow rate
            % calculations.
            
            
            % Fake method, can be used to set a manual FR. If .update is
            % not defined in a subclass, flow rate never changes on mass
            % update sutff in phases, only if the .update method here is
            % manually called including the flow rate parameter.
            if nargin >= 3
                this.setMatterProperties(fFlowRate, arPartials);
            elseif nargin >= 2
                this.setMatterProperties(fFlowRate);
            else
                this.setMatterProperties();
            end
        end
    end
    
    
    methods (Access = protected)
        function [ afInFlowrates, mrInPartials ] = getInFlows(this, sPhase)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow
            %
            %TODO also check for matter.manips.substances, and take the change
            %     due to that also into account ... just as another flow
            %     rate? Should the phase do that?
            
            if nargin < 2, sPhase = 'in'; end
            
            if strcmp(sPhase, 'in'); oPhase = this.oIn.oPhase; else; this.oOut.oPhase; end
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            mrInPartials  = zeros(oPhase.iProcsEXME, this.oMT.iSubstances);
            afInFlowrates = zeros(oPhase.iProcsEXME, 1);
            
            % Creating an array to log which of the flows are not in-flows
            abOutFlows = true(oPhase.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials(iI,:) = mrFlowPartials(abInf, :);
                    afInFlowrates(iI)  = afFlowRates(abInf);
                    abOutFlows(iI)     = false;
                end
            end
            
            % Now we delete all of the rows in the mrInPartials matrix
            % that belong to out-flows.
            if any(abOutFlows)
                mrInPartials(abOutFlows,:)  = [];
                afInFlowrates(abOutFlows,:) = [];
            end
            
            % Check manipulator for partial
            if ~isempty(oPhase.toManips.substance) && ~isempty(oPhase.toManips.substance.afPartialFlows)
                this.warn('getInFlows', 'Unsafe when using a manipulator. Use getPartialInFlows instead!');
            end
        end
        
        
        function aafPartials = getPartialInFlows(this, sPhase)
            % Return matrix with all INWARD flow rates and matrix with 
            % partial masses of each in flow in kg/s per flow / substance
            % To get the total flow rate of each substance into the phase:
            % 
            % afPartialFlows = afFlowRate .* mrPartials(:, iSpecies)
            %
            %TODO clean up - from getFlowData, afFlowRates is afFlowRate
            %     and mrFLowPartails is actually arFlowPartials!
            %     -> simplify!
            
            if nargin < 2, sPhase = 'in'; end
            
            if strcmp(sPhase, 'in'); oPhase = this.oIn.oPhase; else; this.oOut.oPhase; end
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            aafPartials  = zeros(oPhase.iProcsEXME, this.oMT.iSubstances);
            
            % Creating an array to log which of the flows are not in-flows
            aiOutFlows = ones(oPhase.iProcsEXME, 1);
            
            % Get flow rates and partials from EXMEs
            for iI = 1:oPhase.iProcsEXME
                [ fFlowRate, arFlowPartials, ~ ] = oPhase.coProcsEXME{iI}.getFlowData();
                
                % The afFlowRates is a row vector containing the flow rate
                % at each flow, negative being an extraction!
                % mrFlowPartials is matrix, each row has partial ratios for
                % a flow, cols are the different substances.
                
                bInf = (fFlowRate > 0);
                
                if bInf
                    aafPartials(iI,:) = fFlowRate .* arFlowPartials;
                    aiOutFlows(iI)    = 0;
                end
            end
            
            % Now we delete all of the rows in the aafPartials matrix
            % that belong to out-flows.
            if any(aiOutFlows)
                aafPartials(logical(aiOutFlows),:)  = [];
            end
            
            % Check manipulator for partial
            if ~isempty(oPhase.toManips.substance) && ~isempty(oPhase.toManips.substance.afPartialFlows)
                % Was updated just this tick - partial changes in kg/s
                afTmpPartials = oPhase.toManips.substance.afPartialFlows;
                
                if any(afTmpPartials)
                    aafPartials  = [ aafPartials;  afTmpPartials ];
                end
            end
        end
        
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemperature, fPressure)
            % Get missing values from exmes
            
            if (nargin < 2) || isempty(fFlowRate), fFlowRate = this.fFlowRate; end
            
            % We're a p2p, so we're directly connected to EXMEs
            if fFlowRate >= 0
                oExme = this.oIn;
            else
                oExme = this.oOut;
            end
            
            
            if nargin < 3 || isempty(arPartialMass)
                % We also get the molar mass and heat capacity ... however,
                % setMatterProps calculates those anyway so ignore  them.
                [ arPartialMass, ~, ~ ] = oExme.getMatterProperties();
            end
            
            
            % Get matter properties from in exme. 
            [ fPortPressure, fPortTemperature ] = oExme.getPortProperties();
            
            % Check temp and pressure. First temp ... cause that might
            % change in a p2p ... pressure not really.
            if (nargin < 4) || isempty(fTemperature), fTemperature = fPortTemperature; end
            if (nargin < 5) || isempty(fPressure), fPressure = fPortPressure; end
                
            
            setMatterProperties@matter.flow(this, fFlowRate, arPartialMass, fTemperature, fPressure);
        end
    end
end

