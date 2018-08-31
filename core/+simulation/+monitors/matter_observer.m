classdef matter_observer < simulation.monitor
    %MATTER_OBSERVER Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        % How often should the total mass in the system be calculated?
        iMassLogInterval = 100;
        
        
        % Variables holding the sum of lost mass / total mass, species-wise
        mfTotalMass = [];
        mfLostMass  = [];
        
        % Refernces to all phases in the simulation
        aoPhases   = [];
        aoBranches = [];
        
        % References to all flows in the simulation
        aoFlows = [];
    end
    
    methods
        function this = matter_observer(oSimulationInfrastructure)
            this@simulation.monitor(oSimulationInfrastructure, { 'tick_post', 'init_post', 'finish', 'pause' });
            
        end
    end
    
    
    methods (Access = protected)
        
        function onTickPost(this, ~)
            oInfra = this.oSimulationInfrastructure;
            oSim   = oInfra.oSimulationContainer;
            oMT    = oSim.oMT;
            
            if ~isempty(this.aoPhases)
                if mod(oSim.oTimer.iTick, this.iMassLogInterval) == 0
                    iIdx = size(this.mfTotalMass, 1) + 1;
                    
                    % Total mass: sum over all mass stored in all phases, for each
                    % species separately.
                    this.mfTotalMass(iIdx, :) = sum(reshape([ this.aoPhases.afMass ], oMT.iSubstances, []), 2)';
                    
                    % Lost mass: logged by phases if more mass is extracted then
                    % available (for each substance separately).
                    this.mfLostMass(iIdx, :) = sum(reshape([ this.aoPhases.afMassLost ], oMT.iSubstances, []), 2)';
                    
                    %TODO implement methods for that ... break down everything down
                    %     to the moles and compare these?! So really count every
                    %     atom, not the molecules ... compare enthalpy etc?
                end
            else
                iIdx = size(this.mfTotalMass, 1) + 1;
                
                % Total mass: sum over all mass stored in all phases, for each
                % species separately.
                this.mfTotalMass(iIdx, :) = zeros(1, oMT.iSubstances);
                this.mfLostMass(iIdx, :)  = zeros(1, oMT.iSubstances);
            end
        end
        
        
        function onInitPost(this, ~)
            %oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            % Initialize arrays etc
            
            oInfra = this.oSimulationInfrastructure;
            oSim   = oInfra.oSimulationContainer;
            
            % Init the mass log matrices - don't log yet, system's not
            % initialized yet! Just create with one row, for the initial
            % mass log. Subsequent logs dynamically allocate new memory -
            % bad for performance, but only happens every Xth tick ...
            this.mfTotalMass = zeros(0, oSim.oMT.iSubstances);
            this.mfLostMass  = zeros(0, oSim.oMT.iSubstances);
            
            % Going through all systems and their subsystems to gather the
            % phases and branches
            sRootSystemName = oSim.csChildren{1};
            [ this.aoPhases, this.aoBranches ] = this.getPhasesAndBranches(oSim.toChildren.(sRootSystemName), this.aoPhases, this.aoBranches);
            
            iBranches = length(this.aoBranches);
            iPhases   = length(this.aoPhases);
            sEnding1 = sif(iBranches == 1, '', 'es');
            sEnding2 = sif(iPhases   == 1, '',  's');
            fprintf('Model contains %i Branch%s and %i Phase%s.\n', iBranches, sEnding1, iPhases, sEnding2); 
            
            iNumberOfFlows = 0;
            for iBranch = 1:length(this.aoBranches)
                iNumberOfFlows = iNumberOfFlows + this.aoBranches(iBranch).iFlows;
            end
            
            this.aoFlows = matter.flow.empty(0,iNumberOfFlows);
            
            iFlowCounter = 1;
            for iBranch = 1:length(this.aoBranches)
                iNewFlowCounter = iFlowCounter + this.aoBranches(iBranch).iFlows;
                this.aoFlows(iFlowCounter:iNewFlowCounter-1) = this.aoBranches(iBranch).aoFlows;
            end
        end
        
        
        function onFinish(this, ~)
            this.displayMatterBalance();
        end
        
        
        function onPause(this, ~)
            this.displayMatterBalance();
        end
        
        
        function displayMatterBalance(this)
            oSim = this.oSimulationInfrastructure.oSimulationContainer;
            
            % in order to display the correct mass balance it is necessary
            % to add the mass that has to be added/removed since the last
            % massupdate of each phase. Otherwise it is possible that one
            % phase has already used massupdate (and e.g. mass was removed)
            % while the other phase into which the mass would be moved was
            % not updated yet therefore resulting in a mass difference that
            % is only temporary and not actually an error

            mfMassError         = zeros(length(this.aoPhases), oSim.oMT.iSubstances);
            
            for iPhase = 1:length(this.aoPhases)
                fTimeSinceLastMassUpdate = oSim.oTimer.fTime - this.aoPhases(iPhase).fLastMassUpdate;
                if fTimeSinceLastMassUpdate ~= 0
                    mfMassError(iPhase,:) = this.aoPhases(iPhase).afCurrentTotalInOuts * fTimeSinceLastMassUpdate;
                end
            end
            
            mfTotalFinalMass = this.mfTotalMass(end, :) + sum(mfMassError,1);
            
            % DISP balance
            fprintf('+------------------- MATTER BALANCE -------------------+\n');
            
            disp([ '| Mass lost:    ' num2str(sum(this.mfLostMass(end, :))) 'kg' ]);
            disp([ '| Mass balance: ' num2str(sum(this.mfTotalMass(1, :)) - sum(mfTotalFinalMass)) 'kg' ]);
            %fBalance = sum(this.fBalance);
            
            %TODO accuracy from time step!
            %fprinft('| Mass Lost (i.e. negative masses in phases when depleted): %.12f', fBalance);
            
            fprintf('+------------------------------------------------------+\n');
        end
        
        function [ aoPhasesOut, aoBranchesOut ] = getPhasesAndBranches(this, oSystem, aoPhasesIn, aoBranchesIn)
            %GETPHASESANDBRANCHES Returns arrays of phases and branches
            %in the provided system
            % This function takes the provided arrays for phases and
            % branches and appends them with the phases and branches found
            % in the provided system and its subsystems.
            
            % Initializing an empty array for the additional phases we will
            % find.
            aoPhasesNew = matter.phase.empty(0, oSystem.iPhases);
            
            % Initializing a counter
            iPhaseCounter = 1;
            
            % We will have to loop through all of the stores in this
            % system, so we first have to get their names.
            csStores = fieldnames(oSystem.toStores);
            
            % Looping through all stores
            for iStore = 1:length(csStores)
                % Looping through all phases of this store and adding them
                % to our array. 
                for iPhase = 1:oSystem.toStores.(csStores{iStore}).iPhases
                    aoPhasesNew(iPhaseCounter) = oSystem.toStores.(csStores{iStore}).aoPhases(iPhase);
                    % Incrementing the phase counter
                    iPhaseCounter = iPhaseCounter + 1;
                end
            end
            
            % The branches we can just get directly from the system object.
            aoBranchesNew = oSystem.aoBranches;
           
            % If the system has subsystems, we call this function
            % recursively to get the phases and branches from them.
            if oSystem.iChildren > 0
                csChildren = fieldnames(oSystem.toChildren);
                for iChild = 1:length(csChildren)
                    [ aoPhasesNew, aoBranchesNew ] = this.getPhasesAndBranches(oSystem.toChildren.(csChildren{iChild}), aoPhasesNew, aoBranchesNew);
                end
            end
            
            % Finally we append the new arrays to the ones passed in as
            % arguments to this function and we are done. 
            aoPhasesOut   = [ aoPhasesIn, aoPhasesNew ];
            aoBranchesOut = [ aoBranchesIn; aoBranchesNew ];
            
        end
    end
end

