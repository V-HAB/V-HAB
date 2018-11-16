classdef convective < thermal.procs.conductor
    % a general conductor for convective heat transfer, this does not work
    % on its own, you have to create a child class of this and implement
    % the function updateHeatTransferCoefficient for it. As this is very
    % dependant on the use case it cannot be defined generally (to do,
    % create some lib components for most used cases)
    
    properties (SetAccess = protected)
        
        fResistance = 0; % Thermal resistance of connection in [K/W].

        fArea;
        
        fHeatTransferCoefficient = 0; % also known as alpha in most literature
        
        oMassBranch;
        iFlow;
        
        bSetOutdated = false;
    end
    
    methods
        
        function this = convective(oContainer, sName, fArea, oMassBranch, iFlow)
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the conductor type to convective
            this.bConvective = true;
            
            this.fArea = fArea;
            this.oMassBranch = oMassBranch;
            this.iFlow = iFlow;
            
        end
        
        function fResistance = update(this, ~)
            
            this.fHeatTransferCoefficient = this.updateHeatTransferCoefficient();
            
            fResistance = 1 / (this.fHeatTransferCoefficient * this.fArea);
            
            this.fResistance = fResistance;
            
            this.bSetOutdated = false;
        end
        
        function updateHeatTransferCoefficient(this, ~) %#ok<INUSD>
            % overwrite this with child class
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

