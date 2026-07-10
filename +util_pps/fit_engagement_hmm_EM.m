function params = fit_engagement_hmm_EM(move, nIter)

    obs = log(move(:) + 1);
    T = numel(obs);
    K = 2;  % two states

    % ----- initialize -----
    pi0 = [0.5; 0.5];

    A = [0.95 0.05;
         0.05 0.95];

    q = quantile(obs, [0.3 0.7]);
    mu = q(:);                  % state 1 low, state 2 high
    sigma = ones(K,1) * std(obs);

    logLik = zeros(nIter,1);

    for iter = 1:nIter

        % ----- E step: forward-backward -----

        B = zeros(T, K);
        for k = 1:K
            B(:,k) = normpdf(obs, mu(k), sigma(k)) + eps;
        end

        % forward pass with scaling
        alpha = zeros(T,K);
        scale = zeros(T,1);

        alpha(1,:) = pi0' .* B(1,:);
        scale(1) = sum(alpha(1,:));
        alpha(1,:) = alpha(1,:) / scale(1);

        for t = 2:T
            alpha(t,:) = (alpha(t-1,:) * A) .* B(t,:);
            scale(t) = sum(alpha(t,:));
            alpha(t,:) = alpha(t,:) / scale(t);
        end

        % backward pass
        beta = zeros(T,K);
        beta(T,:) = ones(1,K) / scale(T);

        for t = T-1:-1:1
            beta(t,:) = (beta(t+1,:) .* B(t+1,:)) * A';
            beta(t,:) = beta(t,:) / scale(t);
        end

        % posterior state probability
        gamma = alpha .* beta;
        gamma = gamma ./ sum(gamma, 2);

        % posterior transition probability
        xi = zeros(T-1,K,K);

        for t = 1:T-1
            denom = 0;

            for i = 1:K
                for j = 1:K
                    xi(t,i,j) = alpha(t,i) * A(i,j) * B(t+1,j) * beta(t+1,j);
                    denom = denom + xi(t,i,j);
                end
            end

            xi(t,:,:) = xi(t,:,:) / denom;
        end

        % ----- M step -----

        pi0 = gamma(1,:)';

        for i = 1:K
            for j = 1:K
                A(i,j) = sum(xi(:,i,j)) / sum(gamma(1:end-1,i));
            end
        end

        for k = 1:K
            w = gamma(:,k);
            mu(k) = sum(w .* obs) / sum(w);
            sigma(k) = sqrt(sum(w .* (obs - mu(k)).^2) / sum(w));
        end

        logLik(iter) = sum(log(scale + eps));
    end

    % make sure state 1 = low movement, state 2 = high movement
    if mu(1) > mu(2)
        mu = flipud(mu);
        sigma = flipud(sigma);
        pi0 = flipud(pi0);
        A = A([2 1], [2 1]);
        gamma = gamma(:, [2 1]);
    end

    params.pi0 = pi0;
    params.A = A;
    params.mu = mu;
    params.sigma = sigma;
    params.gamma = gamma;
    params.logLik = logLik;
end