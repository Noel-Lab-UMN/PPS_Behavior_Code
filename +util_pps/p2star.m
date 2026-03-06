function sig_str = p2star(p)
if p < 0.001
    sig_str = '***';
elseif p < 0.01
    sig_str = '**';
elseif p < 0.05
    sig_str = '*';
% elseif p < 0.1
%     sig_str = '†';
else
    sig_str = 'n.s.';
end

end