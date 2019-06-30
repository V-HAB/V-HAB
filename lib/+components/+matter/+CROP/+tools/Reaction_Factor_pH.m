function tPmr = Reaction_Factor_pH(tPmr, tpH_Diagram, fpH)
%Function to add the pH effect to the enzyme kinetics as is described in section 4.2.3.8 in the thesis

for j = ['A' 'B' 'C']
    
    % Use the linear interpolation method to calculatethe pH effect factors as
    % is described in section 4.2.3.8 in the thesis
    if fpH <= tpH_Diagram.(j).fpH(1) || fpH >= tpH_Diagram.(j).fpH(11)
        trpH_Factor.(j) = 0;
    else
        for i = 1:11
            if fpH >= tpH_Diagram.(j).fpH(i) && fpH < tpH_Diagram.(j).fpH(i+1)
                trpH_Factor.(j) = (fpH - tpH_Diagram.(j).fpH(i))*(tpH_Diagram.(j).rFactor(i+1) - tpH_Diagram.(j).rFactor(i))...
                    /(tpH_Diagram.(j).fpH(i+1) - tpH_Diagram.(j).fpH(i)) + tpH_Diagram.(j).rFactor(i);
                break
            end
        end
    end
    
    % Add the pH effect factors to the rate constants
    for k = ['a' 'b' 'c' 'd' 'e' 'f' 'g' 'h']
        tPmr.(j).(k).fk_f  = trpH_Factor.(j) * tPmr.(j).(k).fk_f ;
        tPmr.(j).(k).fk_r  = trpH_Factor.(j) * tPmr.(j).(k).fk_r ;
    end
    
end


end