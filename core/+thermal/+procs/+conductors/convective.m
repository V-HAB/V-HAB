classdef convective < thermal.procs.conductor
    % a general conductor for convective heat transfer, this does not work
    % on its own, you have to create a child class of this and implement
    % the function updateHeatTransferCoefficient for it. As this is very
    % dependant on the use case it cannot be defined generally (to do,
    % create some lib components for most used cases)
    
    properties (SetAccess = protected)
        
        fConductivity = 0; % Thermal conductivity of connection in [W/K].

        fArea;
        
        fHeatTransferCoefficient = 0; % also known as alpha in most literature
        
        oMassBranch;
        iFlow;
        
        bRadiative  = false;
        bConvective = true;
        bConductive = false;
        
        bSetOutdated = false;
    end
    
    methods
        
        function this = convective(oContainer, sName, fArea, oMassBranch, iFlow)
            % Create a convective conductor instance
             
            this@thermal.procs.conductor(oContainer, sName);
            
            this.fArea = fArea;
            this.oMassBranch = oMassBranch;
            this.iFlow = iFlow;
            
        end
        
        function fConductivity = update(this, ~)
            
            this.fHeatTransferCoefficient = this.updateHeatTransferCoefficient();
            
            fConductivity = this.fHeatTransferCoefficient * this.fArea;
            
            this.fConductivity = fConductivity;
            
            this.bSetOutdated = false;
        end
        
        function updateHeatTransferCoefficient(this, ~)
            % overwrite this with child class
        end
        
        function updateConnectMatterBranch(this, oMassBranch)
            % TO DO: limit acces to container
            this.oMassBranch = oMassBranch;
        end
        
        function connectMatterSolverBranch(this, ~)
            % necessary for the convective conductor to realise that the
            % mass flow rate has changed
            this.oMassBranch.oHandler.bind('update',@(~)this.setOutdated());
        end
        
        function setOutdated(this,~)
            if ~this.bSetOutdated
                this.oThermalBranch.setOutdated();
                this.bSetOutdated = true;
            end 
        end
            
    end
    
end

