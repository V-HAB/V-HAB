classdef Filter < vsys
% TO DO: Description goes here lazy guy
    
    properties (SetAccess = protected, GetAccess = public)
        
        % number of cells used in the filter model
        iCellNumber = 3;
        
        % initialization struct to set the initial parameters of the filter
        % model
        tInitialization = struct();
        % tInitialization has to be a struct with the following fields:
        %       tfMassAbsorber 	=   Mass struct for the filter material
        %       tfMassFlow      =   Mass struct for the flow material
        %       fTemperature    =   Initial temperature of the filter in K
        %       fFlowVolume     =   free volume for the gas flow in the filter in m³
        %       fAbsorberVolume =   volume of the absorber material in m³
        %       iCellNumber     =   number of cells used in the filter model
        
        % TO DO: other properties (like geometry, maybe Volume should be
        % part of geometry struct?)
        
    end
    
    methods
        function this = Filter(oParent, sName, tInitialization)
            
            this@vsys(oParent, sName, 30);
            
            this.tInitialization = tInitialization;
            this.iCellNumber = tInitialization.iCellNumber;
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, this.sName, (this.tInitialization.fFlowVolume + this.tInitialization.fAbsorberVolume));
            
            % The filter and flow phase total masses provided in the
            % tInitialization struct have to be divided by the number of
            % cells to obtain the tfMass struct for each phase of each
            % cell. The assumption here is that each cell has the same
            % size.
            csAbsorberSubstances = fieldnames(this.tInitialization.tfMassAbsorber);
            for iK = 1:length(csAbsorberSubstances)
                tfMassesAbsorber.(csAbsorberSubstances{iK}) = this.tInitialization.tfMassAbsorber.(csAbsorberSubstances{iK})/this.iCellNumber;
            end
            csFlowSubstances = fieldnames(this.tInitialization.tfMassFlow);
            for iK = 1:length(csFlowSubstances)
                tfMassesFlow.(csFlowSubstances{iK}) = this.tInitialization.tfMassFlow.(csFlowSubstances{iK})/this.iCellNumber;
            end
            
            % Now the phases, exmes, p2ps and branches for the filter model
            % can be created. A for loop is used to allow any number of
            % cells from 2 upwards.
            for iCell = 1:this.iCellNumber
                oFilterPhase = matter.phases.mixture(this.toStores.(this.sName), ['Absorber_',num2str(iCell)], 'solid', tfMassesAbsorber,(this.tInitialization.fAbsorberVolume/this.iCellNumber), this.tInitialization.fTemperature, 1e5);
                
                oFlowPhase = matter.phases.gas(this.toStores.(this.sName), ['Flow_',num2str(iCell)], tfMassesFlow,(this.tInitialization.fFlowVolume/this.iCellNumber), this.tInitialization.fTemperature);
            
                matter.procs.exmes.mixture(oFilterPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.mixture(oFilterPhase, ['Desorption_',num2str(iCell)]);
                
                matter.procs.exmes.gas(oFlowPhase, ['Adsorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Desorption_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Inflow_',num2str(iCell)]);
                matter.procs.exmes.gas(oFlowPhase, ['Outflow_',num2str(iCell)]);
                
                % adding two P2P processors, one for desorption and one for
                % adsorption. Two independent P2Ps are required because it
                % is possible that one substance is currently absorber
                % while another is desorbing which results in two different
                % flow directions that can occur at the same time.
                components.filter.components.Desorption_P2P(this.toStores.(this.sName), ['DesorptionProcessor_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Desorption_',num2str(iCell)], ['Flow_',num2str(iCell),'.Desorption_',num2str(iCell)]);
                components.filter.components.Adsorption_P2P(this.toStores.(this.sName), ['AdsorptionProcessor_',num2str(iCell)], ['Flow_',num2str(iCell),'.Adsorption_',num2str(iCell)], ['Absorber_',num2str(iCell),'.Adsorption_',num2str(iCell)]);
                
                % Each cell is connected to the next cell by a branch, the
                % first and last cell also have the inlet and outlet branch
                % attached that connects the filter to the parent system
                if iCell == 1
                    % Inlet branch
                    matter.branch(this, [this.sName,'.','Inflow_',num2str(iCell)], {}, 'Inlet', 'Inlet');
                elseif iCell == this.iCellNumber
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                    % Outlet branch
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell)], {}, 'Outlet', 'Outlet');
                else
                    % branch between the current and the previous cell
                    matter.branch(this, [this.sName,'.','Outflow_',num2str(iCell-1)], {}, [this.sName,'.','Inflow_',num2str(iCell)], ['Flow',num2str(iCell-1),'toFlow',num2str(iCell)]);
                end
            end
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            for k = 1:length(this.aoBranches)
                solver.matter.manual.branch(this.aoBranches(k));
            end
        end
        
        function setIfFlows(this, sInterface1, sInterface2)
            if nargin == 3
                this.connectIF('Inlet' , sInterface1);
                this.connectIF('Outlet' , sInterface2);
            else
                error([this.sName,' was given a wrong number of interfaces'])
            end
        end
    end
    
     methods (Access = protected)
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            % TO DO: calculate and set the flow rate between the cells
        end
     end
end

