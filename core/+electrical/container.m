classdef container < sys
    %CONTAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % A struct containing all circuits of this electrical system
        toCircuits = struct();
        aoCircuits = electrical.circuit.empty();
        
        csCircuits;
        
        bElectricalSealed;
    
    end
    
    methods
        function this = container(oParent, sName)
            this@sys(oParent, sName);
            
        end
    end
        
    
    methods (Access = public)
        
        function createElectricalStructure(this)
            % Call in child elememts
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).createElectricalStructure();
            end
        end
        
        function addCircuit(this, oCircuit)
            this.toCircuits.(oCircuit.sName) = oCircuit;
            this.aoCircuits(end + 1) = oCircuit;
        end

        
        function sealElectricalStructure(this)
            if this.bElectricalSealed
                this.throw('sealElectricalStructure', 'Already sealed');
            end
            
            
            csChildren = fieldnames(this.toChildren);
            
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                
                this.toChildren.(sChild).sealElectricalStructure();
            end
            
            this.csCircuits = fieldnames(this.toCircuits);
            
            for iI = 1:length(this.csCircuits)
                % Stores need a timer object, to be accessed by the phases
                % to e.g. register updates, find out elapsed time
                this.toCircuits.(this.csCircuits{iI}).seal();
            end
            
            this.bElectricalSealed = true;
        end
        
        
        
        
        
        
    end
    
    
    
    
end

