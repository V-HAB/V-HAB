classdef RCA_Filter < components.filter    
    % RCA Filter
    % inherits from the generic filter
    % two exmes are added to generate the connection to the vacuum 

    properties 
        
    end
    
    methods
        function this = RCA_Filter(varargin)
            this@components.filter(varargin{:});
            
            % Get the respective phases from the generic filter
            oFlow     = this.aoPhases(strcmp({this.aoPhases.sName},'FlowPhase'));
            oFiltered = this.aoPhases(strcmp({this.aoPhases.sName},'FilteredPhase'));
            
            % In order for the solver branches to update correctly and
            % simultaneously, the flow phases has to be 'synced'.
%             oFlow.bSynced = true; 
            
            % Create the according vacuum exmes 
%             matter.procs.exmes.gas(oFlow,     'FlowVolume_Vacuum_Port');            
%             matter.procs.exmes.gas(oFiltered, 'Amine_Vacuum_Port');
            
            
%             this.oProc_sorp = hoth.RCADevelopment.subsystems.RCA.special.RCA_FilterProc_sorp_new(this.oParentSys, this, [this.sName, '_filterproc_sorp'], 'FlowPhase.filterport_sorp', 'FilteredPhase.filterport_sorp', this.sType);
%             this.oProc_deso = hoth.RCADevelopment.Filter.helper.FilterProc_deso(this, [this.sName, '_filterproc_deso'], 'FlowPhase.filterport_deso', 'FilteredPhase.filterport_deso');
        end
    end
    
end