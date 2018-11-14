classdef matter_observer < simulation.monitor
    %MATTER_OBSERVER logs the overall mass balance and mass lost. The
    % difference is that mass balance is: 
    % sum(Mass of all Phases at tick 1) - sum(Mass of all Phases at final tick) 
    % Which means a positive mass balance is actually a reduction in mass
    %
    % This value should be similar in size to the mass lost value, as the
    % primary source of mass balance error are the mass lost values. If you
    % have a large mass balance error check your manipulators! They are the
    % most likely source of such errors!
    %
    % Mass lost sums up the afMassLost properties of alle phases. This
    % occurs if more mass of a single substance is reduced from a phase
    % within a tick than the phase currently stores. As the mass becomes
    % negative in this case, this value is always negative. But a negative
    % afMassLost actually represents creating additional mass, as
    % overwriting a negative value with 0 produces mass! This value should
    % be small, otherwise you have an error in your time step settings!
    %
    % For debugging you can also try using the massbalance_observer, which
    % tries to find the locations in your simulation where the errors occur
    
    properties (SetAccess = protected, GetAccess = public)
        % How often should the total mass in the system be calculated?
        iMassLogInterval = 100;
        
        
        % Variables holding the sum of lost mass / total mass, species-wise
        mfTotalMass = [];
        mfLostMass  = [];
        
        % References to all phases in the simulation
        aoPhases   = [];
        
        % References to all branches in the simulation
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
                    if any([this.aoPhases.bBoundary])
                        this.mfTotalMass(iIdx, :) = sum(reshape([ this.aoPhases(~[this.aoPhases.bBoundary]).afMass ], oMT.iSubstances, []), 2)' +...
                                                    sum(reshape([ this.aoPhases([this.aoPhases.bBoundary]).afMassChange ], oMT.iSubstances, []), 2)';
                    else
                        this.mfTotalMass(iIdx, :) = sum(reshape([ this.aoPhases(~[this.aoPhases.bBoundary]).afMass ], oMT.iSubstances, []), 2)';
                    end
                    
                    % Lost mass: logged by phases if more mass is extracted then
                    % available (for each substance separately).
                    this.mfLostMass(iIdx, :) = sum(reshape([ this.aoPhases.afMassLost ], oMT.iSubstances, []), 2)';
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
            if iBranches == 1; sEnding1 = ''; else; sEnding1 = 'es'; end
            if iPhases == 1; sEnding2 = ''; else; sEnding2 = 's'; end
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
            % arguments to this function and we are done. We need to do
            % some checking for empty arrays first though, because MATLAB
            % will otherwise complain during the concatenation process. 
            if isempty(aoPhasesIn)
                aoPhasesOut = aoPhasesNew;
            else
                aoPhasesOut = [ aoPhasesIn, aoPhasesNew ];
            end
            
            aoBranchesOut = [ aoBranchesIn; aoBranchesNew ];
            
        end
    end
end

