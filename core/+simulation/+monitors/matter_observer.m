classdef matter_observer < simulation.monitor
    %EXECUTION_CONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    
    
    properties (SetAccess = protected, GetAccess = public)
        % How often should the total mass in the system be calculated?
        iMassLogInterval = 100;
        
        
        % Variables holding the sum of lost mass / total mass, species-wise
        mfTotalMass = [];
        mfLostMass  = [];
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
            
            if ~isempty(oMT.aoPhases)
                if mod(oSim.oTimer.iTick, this.iMassLogInterval) == 0
                    iIdx = size(this.mfTotalMass, 1) + 1;
                    
                    % Total mass: sum over all mass stored in all phases, for each
                    % species separately.
                    this.mfTotalMass(iIdx, :) = sum(reshape([ oMT.aoPhases.afMass ], oMT.iSubstances, []), 2)';
                    
                    % Lost mass: logged by phases if more mass is extracted then
                    % available (for each substance separately).
                    this.mfLostMass(iIdx, :) = sum(reshape([ oMT.aoPhases.afMassLost ], oMT.iSubstances, []), 2)';
                    
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

            oMT    = oSim.oMT;
            
            mfMassError         = zeros(length(oMT.aoPhases), oMT.iSubstances);
            
            for iPhase = 1:length(oMT.aoPhases)
                fTimeSinceLastMassUpdate = oSim.oTimer.fTime - oMT.aoPhases(iPhase).fLastMassUpdate;
                if fTimeSinceLastMassUpdate ~= 0
                    mfMassError(iPhase,:) = oMT.aoPhases(iPhase).afCurrentTotalInOuts * fTimeSinceLastMassUpdate;
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
    end
end

