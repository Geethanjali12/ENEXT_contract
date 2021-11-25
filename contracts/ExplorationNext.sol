// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interface/IUniswapV2Router.sol";
import "./interface/IUniswapV2Factory.sol";
import "./interface/IUniswapV2Pair.sol";

contract ExplorationNext is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private pausedAddress;
    mapping (address => bool) private _isExcluded;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcludedFromMaxTx;
    mapping (address => bool) private _isIncludedInFee;
    mapping (address => bool) private _previousTokenBalanceTransfered;
    address[] private _excluded;

    address UNISWAPV2ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address devAddress = 0xdDb9a4461e5fF9f8035770E81209979D722697D4;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 387000000  * 10**18;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private constant _name = "ExplorationNext";
    string private constant _symbol = "ENEXT";
    uint8 private constant _decimals = 18;


    uint256 public reflectionFee = 3;
    uint256 private previousReflectionFee = reflectionFee;

    uint256 public liquidityFee = 1;
    uint256 private previousLiquidityFee = liquidityFee;

    uint256 public marketingWalletFee = 1;
    uint256 private previousMarketingWalletFee = marketingWalletFee;

    bool public enableFee;
 
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

     
uint256 public minLiquidity ;
    uint256 public feeEnable;

    uint256 public _maxTxAmount = 5000000 * 10**18;

 uint256 private numTokensSellToAddToLiquidity = 500000 * 10**18;    

    event FeeEnable(bool enableFee);
    event SetMaxTxPercent(uint256 maxPercent);
    event SetTaxFeePercent(uint256 taxFeePercent);
    event ExternalTokenTransfered(address externalAddress,address toAddress, uint amount);
    event RedistributionFee(uint256 amount);
    event liqFee(uint256 tLiquidity);
    event marketWalletFee(uint256 amount);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped,uint256 ethReceived,uint256 tokensIntoLiqudity);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () {
        
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(UNISWAPV2ROUTER);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        emit Transfer(address(0), _msgSender(), _tTotal);
 
    }

    /** 
     * Returns the name of the token.
     */
    function name() external view virtual override returns (string memory) {
        return _name;
    }

    /**
     * Returns the symbol of the token.
     */
    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * Returns the number of decimals 
     */
    function decimals() external view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view virtual override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) external view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    
    function isExcludedFromReward(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    function isExcludedFromMaxTx(address account) external view returns (bool) {
        return _isExcludedFromMaxTx[account];
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already included");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) public onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    function setTaxFeePercent(uint256 fee) external onlyOwner {
        reflectionFee = fee;
        emit SetTaxFeePercent(reflectionFee);
    }

    function setEnableFee(bool enableTax) external onlyOwner {
        enableFee = enableTax;
        emit FeeEnable(enableTax);
    }


    function takeReflectionFee(uint256 rFee, uint256 tFee) internal {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
        emit RedistributionFee(tFee);
    }

   function takeLiquidityFee(uint256 rliquidityFee, uint256 tliquidityFee)
        internal
    {
        if (_isExcluded[address(this)]) {
            _rOwned[address(this)] = _rOwned[address(this)].add(rliquidityFee);
        } else {
            _rOwned[address(this)] = _rOwned[address(this)].add(rliquidityFee);
            _tOwned[address(this)] = _tOwned[address(this)].add(tliquidityFee);
        }
        emit liqFee(tliquidityFee);
    }

    function takeMarketingWalletFee(uint256 rMarketingWalletFee, uint256 tMarketingWalletFee) internal {
       if (_isExcluded[address(devAddress)]) {
            _rOwned[address(devAddress)] = _rOwned[address(devAddress)].add(rMarketingWalletFee);
        } else {
            _rOwned[address(devAddress)] = _rOwned[address(devAddress)].add(rMarketingWalletFee);
            _tOwned[address(devAddress)] = _tOwned[address(devAddress)].add(tMarketingWalletFee);
        }
        emit marketWalletFee(tMarketingWalletFee);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function getTValues(uint256 amount) internal view returns (uint256, uint256, uint256,uint256) {
        uint256 tAmount = amount;
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidityFee = calculateLiquidityFee(tAmount);
        uint256 tMarketingWalletFee = calculateMarketingWalletFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidityFee).sub(tMarketingWalletFee);
        return (tTransferAmount, tFee, tLiquidityFee,tMarketingWalletFee);
    }

    function getRValues(uint256 amount, uint256 tFee, uint256 tLiquidityFee, uint256 tMarketingWalletFee) internal view returns (uint256,uint256, uint256,uint256,uint256) {
        uint256 currentRate = getRate();
        uint256 tAmount = amount;
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidityfee = tLiquidityFee.mul(currentRate);
        uint256 rMarketingWalletFee = tMarketingWalletFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidityfee).sub(rMarketingWalletFee);
        return (rAmount, rTransferAmount, rFee, rLiquidityfee,rMarketingWalletFee);
    }

    function getRate() internal view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function getCurrentSupply() internal view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

      function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    
    function calculateTaxFee(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(reflectionFee).div(
            10**2
        );
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(liquidityFee).div(
            10**2
        );
    }
    function calculateMarketingWalletFee(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(marketingWalletFee).div(
            10**2
        );
    }
    
    function removeAllFee() internal {
        if(reflectionFee == 0 && liquidityFee == 0 && marketingWalletFee == 0) return;
        
        previousReflectionFee = reflectionFee;
        reflectionFee = 0;
        
        previousLiquidityFee = liquidityFee;
        liquidityFee = 0;

        previousMarketingWalletFee = marketingWalletFee;
        marketingWalletFee = 0;
    }
 
    function restoreAllFee() internal {
        reflectionFee = previousReflectionFee;
        liquidityFee = previousLiquidityFee;
        marketingWalletFee = previousMarketingWalletFee;
    }

     function isIncludedInFee(address account) external view returns(bool) {
        return _isIncludedInFee[account];
    }
   
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        
        //_beforeTokenTransfer(from, to);
        
        //uint256 senderBalance = balanceOf(from);
        //require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        uint256 contractTokenBalance = balanceOf(address(this));
         bool previousenableFee;

         if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
         //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        if (
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            if (enableFee == true) {
                previousenableFee = enableFee;
                enableFee = false;
            }
            //add liquidity
            swapAndLiquify(contractTokenBalance);
            if (previousenableFee == true) {
                enableFee = true;
            }
        }
        require(
            contractTokenBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
       
        //transfer amount, it will take tax, burn and charity amount
        _tokenTransfer(from,to,amount,takeFee);
    }
    
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) internal {
        if(!takeFee)
            removeAllFee();
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee)
            restoreAllFee();
    }
  
    function _transferStandard(address sender, address recipient, uint256 tAmount) internal {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidityFee, uint256 tMarketingWalletFee) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee,uint256 rLiquidityFee,uint256 rMarketingWalletFee) = getRValues(tAmount, tFee, tLiquidityFee,tMarketingWalletFee);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        takeReflectionFee(rFee, tFee);
        takeLiquidityFee(rLiquidityFee, tLiquidityFee);
        takeMarketingWalletFee(rMarketingWalletFee, tMarketingWalletFee);
        emit Transfer(sender, recipient, tTransferAmount);

    }
    
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 tTransferAmount, uint256 tFee,uint256 tLiquidityFee, uint256 tMarketingWalletFee) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rLiquidityFee, uint256 rMarketingWalletFee) = getRValues(tAmount, tFee,tLiquidityFee,tMarketingWalletFee);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        takeReflectionFee(rFee, tFee);
        takeLiquidityFee(rLiquidityFee, tLiquidityFee);
        takeMarketingWalletFee(rMarketingWalletFee, tMarketingWalletFee);
        emit Transfer(sender, recipient, tTransferAmount);

    }
    
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidityFee, uint256 tMarketingWalletFee) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rLiquidityFee, uint256 rMarketingWalletFee) = getRValues(tAmount, tFee,tLiquidityFee,tMarketingWalletFee);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        takeReflectionFee(rFee, tFee);
        takeLiquidityFee(rLiquidityFee, tLiquidityFee);
        takeMarketingWalletFee(rMarketingWalletFee, tMarketingWalletFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) internal {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidityFee, uint256 tMarketingWalletFee) = getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 rLiquidityFee, uint256 rMarketingWalletFee) = getRValues(tAmount, tFee,tLiquidityFee,tMarketingWalletFee);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        takeReflectionFee(rFee, tFee);
        takeLiquidityFee(rLiquidityFee, tLiquidityFee);
        takeMarketingWalletFee(rMarketingWalletFee, tMarketingWalletFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

     function withdrawToken(address _tokenContract, uint256 _amount)
        external
        onlyOwner
    {
        require(_tokenContract != address(0), "Address cant be zero address");
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.transfer(msg.sender, _amount);
        emit ExternalTokenTransfered(_tokenContract, msg.sender, _amount);
    }


    function _beforeTokenTransfer(address from, address to) internal virtual { 
    }
}